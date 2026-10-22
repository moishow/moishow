package com.moishow.identity;
import jakarta.persistence.*;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Repository;
import java.util.*;
import static com.moishow.identity.Models.*;
@Repository @Profile("db")
class Store {
 @PersistenceContext EntityManager em;
 <T> T find(Class<T> type,UUID id){var row=em.find(type,id);ApiProblem.require(row!=null,404,"NOT_FOUND");return row;}
 <T> T lock(Class<T> type,UUID id){var row=em.find(type,id);ApiProblem.require(row!=null,404,"NOT_FOUND");em.refresh(row,LockModeType.PESSIMISTIC_WRITE);return row;}
 <T> T save(T entity){em.persist(entity);return entity;}
 <T> List<T> list(Class<T> type,String jpql,Object...args){var q=em.createQuery(jpql,type);for(int i=0;i<args.length;i++)q.setParameter(i+1,args[i]);return q.getResultList();}
 <T> T one(Class<T> type,String jpql,Object...args){var rows=list(type,jpql,args);return rows.isEmpty()?null:rows.getFirst();}
 Membership member(UUID club,UUID user){return one(Membership.class,"from Membership where clubId=?1 and userId=?2",club,user);}
 boolean active(UUID club,UUID user){var m=member(club,user);return m!=null&&m.status.equals("ACTIVE")&&!m.blacklisted;}
 boolean admin(UUID club,UUID user){var m=member(club,user);return active(club,user)&&(m.role.equals("OWNER")||m.role.equals("ADMIN"));}
 ServiceSession session(String hash){return em.find(ServiceSession.class,hash);}
 void flush(){em.flush();}
}
