import { readFile, readdir, access } from 'node:fs/promises';
import { join, resolve, dirname, relative } from 'node:path';
const root = resolve(import.meta.dirname, '..');
const failures = [];
const catalog = JSON.parse(await readFile(join(root,'design/system/screen-catalog.json'),'utf8'));
const ids = new Set();
for (const screen of catalog) {
  if(ids.has(screen.id)) failures.push(`duplicate screen ${screen.id}`);
  ids.add(screen.id);
  if(!['money','community'].includes(screen.surface)) failures.push(`invalid surface ${screen.id}`);
  if(!screen.note || !screen.actions.length) failures.push(`incomplete handoff ${screen.id}`);
}
for(const screen of catalog) for(const action of screen.actions) if(!ids.has(action.target)) failures.push(`unknown target ${screen.id} -> ${action.target}`);
const pages=[];
async function walk(folder){for(const file of await readdir(folder,{withFileTypes:true})){if(['.git','review','node_modules','.superpowers'].includes(file.name))continue;const p=join(folder,file.name);if(file.isDirectory())await walk(p);else if(file.name.endsWith('.html'))pages.push(p);}}
await walk(root);
let references=0;
for(const page of pages){
 const html=await readFile(page,'utf8');
 const baseMatch=html.match(/<base\s+href=["']([^"']+)/i);
 const base=new URL(baseMatch?.[1]||'', 'https://local/'+relative(root,page).replaceAll('\\','/'));
 for(const match of html.matchAll(/\b(?:href|src|data-md-src)=["']([^"']+)["']/g)){
  const ref=match[1];if(ref.includes('${')||ref.startsWith('data:'))continue;
  const target=new URL(ref,base);if(target.origin!=='https://local')continue;
  references++;try{await access(join(root,decodeURIComponent(target.pathname)));}catch{failures.push(`${relative(root,page)} missing ${ref}`);}
 }
}
const policy=await readFile(join(root,'docs/product/POLICY.md'),'utf8');
for(const required of ['72시간','모임장에게 귀속','부분 납부','실제 입금','동의 대기','푸시','50점'])if(!policy.includes(required))failures.push(`missing policy ${required}`);
for(const name of ['홈','회원','모임','피드']){
 const doc=await readFile(join(root,'docs/scenario/domains',`${name}.md`),'utf8');
 if(!doc.includes('POLICY.md'))failures.push(`no canonical policy reference: ${name}`);
}
if(failures.length){console.error(failures.join('\n'));process.exitCode=1;}else console.log(JSON.stringify({screens:catalog.length,pages:pages.length,localReferences:references,failures:0}));
