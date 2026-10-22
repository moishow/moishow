package com.moishow.identity;
import org.quartz.*;
import org.springframework.context.annotation.*;
import org.springframework.boot.ApplicationRunner;
import static org.quartz.JobBuilder.newJob;
import static org.quartz.TriggerBuilder.newTrigger;
import static org.quartz.SimpleScheduleBuilder.simpleSchedule;
/** JDBC trigger survives restart. Context holds only this process's service proxy, never serialized beans. */
@Configuration @Profile("db")
public class PlatformJobs {
 @Bean ApplicationRunner platformScheduler(Scheduler scheduler,PlatformService service){return args->{
  scheduler.getContext().put("platformService",service);
  JobKey key=new JobKey("platform-workflows","moishow");
  if(!scheduler.checkExists(key))try{scheduler.scheduleJob(newJob(Tick.class).withIdentity(key).storeDurably().requestRecovery().build(),newTrigger().withIdentity("platform-minute","moishow").forJob(key).startNow().withSchedule(simpleSchedule().withIntervalInSeconds(60).repeatForever().withMisfireHandlingInstructionNextWithRemainingCount()).build());}catch(ObjectAlreadyExistsException concurrentNode){}
 };}
 @DisallowConcurrentExecution public static class Tick implements Job {
  @Override public void execute(JobExecutionContext context)throws JobExecutionException{try{((PlatformService)context.getScheduler().getContext().get("platformService")).tick();}catch(Exception error){throw new JobExecutionException(error);}}
 }
}
