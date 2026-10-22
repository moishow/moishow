import { assertMoney, assertId, sumMoney, uniqueIds, splitEven, splitProportionally } from './money.mjs';

export function calculateCancellation({ paid, fee }) {
  assertMoney(paid, 'paid');
  assertMoney(fee, 'fee');
  return { charge: fee, refund: Math.max(0, paid - fee), outstanding: Math.max(0, fee - paid) };
}

export function settleRound({ id, expense, attendeeIds, cancellations = [] }) {
  assertId(id, 'roundId');
  assertMoney(expense, 'expense');
  const attendees = uniqueIds(attendeeIds, 'attendeeId');
  if (!Array.isArray(cancellations)) throw new TypeError('cancellations must be an array');
  uniqueIds(cancellations.map(item => item.userId), 'cancellation userId');
  for (const item of cancellations) {
    assertMoney(item.fee, 'cancellation fee');
    assertMoney(item.received, 'received cancellation fee');
    if (item.received > item.fee) throw new RangeError('received fee cannot exceed the agreed fee; refund excess original prepayment separately');
    if (attendees.includes(item.userId)) throw new TypeError('one user cannot be an attendee and cancellation payer in the same round');
  }
  const receivedCancellation = sumMoney(cancellations.map(item => item.received));
  const pendingCancellation = sumMoney(cancellations.map(item => item.fee - item.received));
  const attendeeBurden = Math.max(0, expense - receivedCancellation);
  const excess = Math.max(0, receivedCancellation - expense);
  const { allocations: cancellationRefunds, remainder: reserveRemainder } = splitProportionally(
    excess, cancellations.map(item => ({ userId: item.userId, amount: item.received })),
  );
  const refundsById = new Map(cancellationRefunds.map(item => [item.userId, item.amount]));
  const cancellationCharges = cancellations.map(item => ({ userId: item.userId, amount: item.fee - refundsById.get(item.userId) })).sort((a,b) => a.userId < b.userId ? -1 : 1);
  return {
    roundId: id,
    expense,
    attendeeCharges: attendees.length ? splitEven(attendeeBurden, attendees) : [],
    cancellationCharges,
    cancellationRefunds,
    receivedCancellation,
    pendingCancellation,
    reserveRemainder,
    hostContribution: attendees.length === 0 ? attendeeBurden : 0,
  };
}

function verifyLedger(items, ids, name) {
  if (!Array.isArray(items)) throw new TypeError(`${name} must be an array`);
  for (const item of items) {
    assertId(item.id, `${name} id`);
    assertId(item.userId, `${name} userId`);
    assertMoney(item.amount, `${name} amount`);
    if (typeof item.confirmed !== 'boolean') throw new TypeError(`${name} confirmed must be explicit boolean`);
    if (ids.has(item.id)) throw new TypeError(`duplicate ledger id: ${item.id}`);
    ids.add(item.id);
  }
}

export function settleEvent({ hostId, rounds, receipts = [], refunds = [] }) {
  assertId(hostId, 'hostId');
  if (!Array.isArray(rounds)) throw new TypeError('rounds must be an array');
  uniqueIds(rounds.map(round => round.id), 'roundId');
  const ledgerIds = new Set();
  verifyLedger(receipts, ledgerIds, 'receipts');
  verifyLedger(refunds, ledgerIds, 'refunds');
  sumMoney(receipts.filter(item => item.confirmed).map(item => item.amount));
  sumMoney(refunds.filter(item => item.confirmed).map(item => item.amount));
  const results = rounds.map(settleRound);
  const obligations = new Map();
  function addCharge(userId, amount) {
    obligations.set(userId, sumMoney([obligations.get(userId) ?? 0, amount]));
  }
  for (const result of results) {
    for (const item of [...result.attendeeCharges, ...result.cancellationCharges]) addCharge(item.userId, item.amount);
    if (result.hostContribution) addCharge(hostId, result.hostContribution);
  }
  const received = new Map();
  const refunded = new Map();
  for (const [items, totals] of [[receipts, received], [refunds, refunded]]) {
    for (const item of items) {
      if (!item.confirmed) continue;
      totals.set(item.userId, sumMoney([totals.get(item.userId) ?? 0, item.amount]));
    }
  }
  const allocatedFeeReceipts = new Map();
  for (const round of rounds) {
    for (const item of round.cancellations ?? []) {
      allocatedFeeReceipts.set(item.userId, sumMoney([allocatedFeeReceipts.get(item.userId) ?? 0, item.received]));
    }
  }
  for (const [userId, amount] of allocatedFeeReceipts) {
    if (amount > (received.get(userId) ?? 0)) throw new RangeError('cancellation contributions exceed confirmed receipts for this event');
  }
  const allIds = [...new Set([...obligations.keys(), ...received.keys(), ...refunded.keys()])].sort();
  const positions = allIds.map(userId => {
    const obligation = obligations.get(userId) ?? 0;
    const paid = received.get(userId) ?? 0;
    const returned = refunded.get(userId) ?? 0;
    const positiveTerms = sumMoney([obligation, returned]);
    const net = positiveTerms - paid;
    return { userId, obligation, received: paid, refunded: returned, net, additional: Math.max(0, net), refund: Math.max(0, -net) };
  });
  return {
    rounds: results,
    positions,
    totalExpense: sumMoney(results.map(item => item.expense)),
    pendingCancellation: sumMoney(results.map(item => item.pendingCancellation)),
    reserveRemainder: sumMoney(results.map(item => item.reserveRemainder)),
    hostContribution: sumMoney(results.map(item => item.hostContribution)),
  };
}
