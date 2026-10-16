const fs=require('fs'),vm=require('vm'),assert=require('assert'),{randomUUID}=require('crypto');
const elements=new Map(),element=s=>{if(!elements.has(s))elements.set(s,{innerHTML:'',textContent:'',value:s==='#jsuSet'?'1':'',classList:{toggle(){}},showModal(){}});return elements.get(s)};
const nav=['home','topics','uasa','matriks','progress','classes'].map(p=>({dataset:{page:p},classList:{toggle(){}}}));let storage=new Map(),ctx={console,Math,Date,Blob,URL,crypto:{randomUUID},setTimeout:()=>0,setInterval:()=>1,clearInterval(){},localStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)},document:{querySelector:element,querySelectorAll:()=>nav,createElement:()=>({click(){}})},window:{scrollTo(){},print(){}},confirm:()=>true,alert:msg=>{throw Error(msg)}};vm.createContext(ctx);
for(let f of ['supabase-config.js','cloud.js','bank.js','app.js'])vm.runInContext(fs.readFileSync(f,'utf8'),ctx);
vm.runInContext(`
for(let p of Object.keys(labels)){go(p);if(!app.innerHTML.length)throw Error('Empty '+p)}
go('topics',1);startTopic('ops');for(let i=0;i<10;i++){let q=session.questions[i];jump(i);session.answers[q.id].value=q.answer;checkAnswer()}askFinish();if(totals().score!==10||!session.saved||totals().pending)throw Error('Topic scoring');
for(let y=1;y<=6;y++)for(let s=1;s<=3;s++)for(let mode of ['uasa','matriks']){
 if(mode==='uasa'&&y<4)continue;
 go(mode,y);startExam(mode,s);for(let i=0;i<session.questions.length;i++){jump(i);let q=session.questions[i];saveAnswer(q.answer);saveWorking(q.explain)}askFinish();if(totals().score!==50||totals().pending!==0)throw Error(mode+' scoring '+y+' '+s);
}
go('uasa',4);startExam('uasa',1);for(let q of session.questions)session.answers[q.id]={value:'wrong'};finish(false);if(totals().score!==0||totals().pending)throw Error('Wrong scoring');
go('uasa',4);startExam('uasa',1);finish(true);if(totals().score!==0||!session.expired)throw Error('Timeout scoring');
go('progress');exportCSV();if(!equivalent('6/8','3/4')||!equivalent('RM 25.50','25.5')||equivalent('','0')||equivalent('2','3'))throw Error('Normalization');
if(typeof markItem!=='undefined'||labels.teacher)throw Error('Manual review still exposed');
console.log('PASS: six views, all 27 exam sets auto-score 50/50; wrong/empty/timeout score 0; no manual review; local records and CSV; equivalent answers.');
`,ctx);
