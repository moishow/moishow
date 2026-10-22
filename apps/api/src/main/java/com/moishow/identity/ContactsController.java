package com.moishow.identity;

import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

/** Known social relationships only. Selecting a contact grants no financial authority. */
@RestController
@Profile("db")
@RequestMapping("/api/v1/me/contacts")
class ContactsController {
    private final JdbcTemplate sql;
    ContactsController(JdbcTemplate sql) { this.sql = sql; }

    @GetMapping
    @Transactional(readOnly = true)
    List<Map<String, Object>> contacts(@AuthenticationPrincipal Actor actor,
            @RequestParam(defaultValue = "0") int offset,
            @RequestParam(defaultValue = "50") int limit) {
        CommunityService.pagination(offset, limit);
        return sql.queryForList("""
                with event_people as (
                  select id event_id, host_id user_id from club_event
                  union
                  select r.event_id, p.user_id from participation p
                    join event_round r on r.id=p.round_id where p.status='CONFIRMED'
                ), known as (
                  select b.user_id from membership a
                    join membership b on b.club_id=a.club_id
                    join club c on c.id=a.club_id
                    where a.user_id=? and a.status='ACTIVE' and b.status='ACTIVE'
                      and not a.blacklisted and not b.blacklisted and c.status='ACTIVE'
                  union
                  select b.user_id from event_people a join event_people b on b.event_id=a.event_id
                    where a.user_id=?
                  union
                  select a.target_id from community_follow a
                    join community_follow b on b.user_id=a.target_id and b.target_id=a.user_id
                    where a.user_id=?
                )
                select u.id, u.nickname from known k join app_user u on u.id=k.user_id
                  where u.id<>? and u.status='ACTIVE'
                    and not exists(select 1 from community_block b
                      where (b.user_id=? and b.target_id=u.id) or (b.target_id=? and b.user_id=u.id))
                  order by u.nickname,u.id limit ? offset ?
                """, actor.userId(), actor.userId(), actor.userId(), actor.userId(),
                actor.userId(), actor.userId(), limit, offset);
    }
}
