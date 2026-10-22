/** Pure integer-KRW helpers. No I/O, timestamps or external payment claims. */
export function assertMoney(value, name = 'amount') {
  if (!Number.isSafeInteger(value) || value < 0) throw new RangeError(`${name} must be a non-negative safe integer in KRW`);
  return value;
}

export function sumMoney(values) {
  let total = 0;
  for (const value of values) {
    assertMoney(value);
    total += value;
    assertMoney(total, 'total');
  }
  return total;
}

export function assertId(value, name = 'id') {
  if (typeof value !== 'string' || !value.trim()) throw new TypeError(`${name} must be a non-empty string`);
  return value;
}

export function uniqueIds(values, name = 'ids') {
  if (!Array.isArray(values)) throw new TypeError(`${name} must be an array`);
  const seen = new Set();
  for (const id of values) {
    assertId(id, name);
    if (seen.has(id)) throw new TypeError(`duplicate ${name}: ${id}`);
    seen.add(id);
  }
  return [...seen].sort();
}

export function splitEven(amount, userIds) {
  assertMoney(amount);
  const ids = uniqueIds(userIds, 'userId');
  if (ids.length === 0) {
    if (amount !== 0) throw new RangeError('cannot allocate a positive amount without attendees');
    return [];
  }
  const base = Math.floor(amount / ids.length);
  const remainder = amount % ids.length;
  return ids.map((userId, index) => ({ userId, amount: base + (index < remainder ? 1 : 0) }));
}

export function splitProportionally(amount, weights) {
  assertMoney(amount);
  if (!Array.isArray(weights)) throw new TypeError('weights must be an array');
  uniqueIds(weights.map(item => item.userId), 'weight userId');
  const total = sumMoney(weights.map(item => item.amount));
  if (amount > 0 && total === 0) throw new RangeError('positive allocation requires positive weights');
  const allocations = [...weights].sort((a,b) => a.userId < b.userId ? -1 : a.userId > b.userId ? 1 : 0).map(item => ({
    userId: item.userId,
    amount: total === 0 ? 0 : Number(BigInt(amount) * BigInt(item.amount) / BigInt(total)),
  }));
  return { allocations, remainder: amount - sumMoney(allocations.map(item => item.amount)) };
}
