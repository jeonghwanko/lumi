'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=__dirname;
const context={window:{}};vm.createContext(context);
vm.runInContext(fs.readFileSync(path.join(root,'puzzle-atlas-data.js'),'utf8'),context);
vm.runInContext(fs.readFileSync(path.join(root,'puzzle-theme.js'),'utf8'),context);
const theme=context.window.PuzzleTileTheme;
const renderer=require('./puzzle-tile-renderer.js');
const expectedHash='309463da9235aea05d8cc0398508c3d02e2b0a534a2258f3940bd14558ad47c6';
function mock(){const calls=[];const ctx={};for(const name of ['save','restore','beginPath','moveTo','arcTo','closePath','clip','drawImage'])ctx[name]=(...args)=>calls.push({name,args});return {ctx,calls};}
test('approved six-color theme, stable logical indices and complete palette',()=>{
 assert.equal(theme.id,'colored-cats-v4');assert.deepEqual(Array.from(theme.labels),['빨강 고양이','노랑 고양이','초록 고양이','파랑 고양이','보라 고양이','주황 고양이']);
 assert.equal(theme.palette.length,6);assert.equal(new Set(theme.palette.map(p=>p.mid)).size,6);
 for(const p of theme.palette)for(const key of ['hi','mid','dk','edge'])assert.match(p[key],/^#[0-9a-f]{6}$/i);
 assert.ok(Object.isFrozen(theme)&&Object.isFrozen(theme.atlas.frames));
});
test('embedded atlas is byte-identical to the approved unmodified PNG',()=>{
 const source=fs.readFileSync(path.join(root,theme.atlas.sourcePath));
 assert.equal(crypto.createHash('sha256').update(source).digest('hex'),expectedHash);
 const embedded=Buffer.from(theme.atlas.src.split(',')[1],'base64');assert.deepEqual(embedded,source);
 assert.equal(source.readUInt32BE(16),1536);assert.equal(source.readUInt32BE(20),1024);
});
test('six integer frames stay inside source, never overlap, and validate exact dimensions',()=>{
 assert.equal(renderer.validAtlas(theme.atlas,1536,1024),true);assert.equal(renderer.validAtlas(theme.atlas,1024,1536),false);
 for(const f of theme.atlas.frames)for(const n of Object.values(f))assert.equal(Number.isInteger(n),true);
 const bad=JSON.parse(JSON.stringify(theme.atlas));bad.frames[1]=bad.frames[0];assert.equal(renderer.validAtlas(bad,1536,1024),false);
 bad.frames[1]={x:-1,y:0,width:20,height:20,radius:10};assert.equal(renderer.validAtlas(bad,1536,1024),false);
});
test('native-resolution cache clips each exact atlas frame before drawing or scaling',()=>{
 for(const frame of theme.atlas.frames){const {ctx,calls}=mock();const canvas={getContext:type=>{assert.equal(type,'2d');return ctx;}};const image={tag:'approved-atlas'};
 assert.equal(renderer.cacheFrame(()=>canvas,image,frame),canvas);assert.equal(canvas.width,frame.width);assert.equal(canvas.height,frame.height);
 assert.ok(calls.findIndex(c=>c.name==='clip')<calls.findIndex(c=>c.name==='drawImage'));
 assert.deepEqual(calls.find(c=>c.name==='drawImage').args,[image,frame.x,frame.y,frame.width,frame.height,0,0,frame.width,frame.height]);
 assert.equal(calls.filter(c=>c.name==='arcTo').length,4);assert.ok(calls.filter(c=>c.name==='arcTo').every(c=>c.args[4]===100));
 assert.equal(calls.at(-1).name,'restore');}
});
test('all board and goal draw sizes use only cached tile pixels with proportional clipping',()=>{
 for(const f of theme.atlas.frames)for(const cell of [28,36,44,64,96])for(const selected of [1,1.06]){
  const {ctx,calls}=mock(),image={tag:'cached-tile'};renderer.draw(ctx,image,f,cell*.52*selected);
  const args=calls.find(c=>c.name==='drawImage').args;assert.deepEqual(args.slice(0,5),[image,0,0,f.width,f.height]);
  assert.ok(args[7]<cell&&args[8]<cell);assert.ok(calls.findIndex(c=>c.name==='clip')<calls.findIndex(c=>c.name==='drawImage'));
  const expectedRadius=100*(cell*.52*selected*1.68)/Math.max(f.width,f.height);assert.ok(Math.abs(calls.find(c=>c.name==='arcTo').args[4]-expectedRadius)<1e-9);
 }
});
test('selection stroke stays within its own cell for mobile and desktop sizes',()=>{
 for(const cell of [28,36,44,64,96]){const f=renderer.selectionFrame(cell,0,0);assert.ok(f.side+f.lineWidth<cell);assert.ok(f.radius>0);}
});
test('Canvas state restores even when a draw fails',()=>{const {ctx,calls}=mock();ctx.drawImage=()=>{throw Error('mock failure')};assert.throws(()=>renderer.draw(ctx,{},theme.atlas.frames[0],20));assert.equal(calls.at(-1).name,'restore');});
test('board, goal icons and Pixi baking share cat renderer; theme text replaces drink instructions',()=>{
 const html=fs.readFileSync(path.join(root,'lumi.html'),'utf8');assert.match(html,/PuzzleTileRenderer\.draw\(ctx,rec\.img,rec\.frame,s\)/);
 assert.match(html,/texFruit\[type\] = bakeOne\(function \(\) \{ drawFruit\(type, BAKE_S\)/);
 assert.match(html,/const PALETTE = window\.PuzzleTileTheme\.palette/);assert.doesNotMatch(html,/같은 음료를 맞춰/);
 assert.ok(html.indexOf('puzzle-atlas-data.js')<html.indexOf('puzzle-theme.js'));assert.ok(html.indexOf('puzzle-tile-renderer.js')<html.indexOf('<script>'));
});
function loaderHarness(options={}){
 const html=fs.readFileSync(path.join(root,'lumi.html'),'utf8');
 const loader=html.slice(html.indexOf('  function loadFruitSprites()'),html.indexOf('  function drawFruitSprite('));
 const images=[];let caches=0,callbacks=0;
 class FakeImage{constructor(){this.naturalWidth=1536;this.naturalHeight=1024;images.push(this);}set src(value){this.source=value;}}
 const c={window:{PuzzleTileTheme:theme,PuzzleTileRenderer:renderer},Image:FakeImage,
 document:{createElement:tag=>{assert.equal(tag,'canvas');if(options.failCache&&++caches===2)throw Error('cache failure');return {getContext:()=>mock().ctx};}},
 TYPES:6,fruitSprites:[],fruitSpritesReady:false,fruitSpritesLoading:false,fruitBakeUsedSprites:false,
 onFruitSpritesMaybeReady:()=>{callbacks++;},FRUIT_SPRITE_FILES:[]};
 vm.createContext(c);vm.runInContext(loader,c);return {c,images,load:()=>vm.runInContext('loadFruitSprites()',c),callbacks:()=>callbacks};
}
test('actual atlas loader uses one image, caches all six, and signals readiness once',()=>{
 const h=loaderHarness();h.load();h.load();assert.equal(h.images.length,1);assert.ok(h.c.fruitSprites.every(r=>!r.ready));
 h.images[0].onload();assert.ok(h.c.fruitSprites.every(r=>r.ready));assert.equal(h.callbacks(),1);
 for(let i=0;i<6;i++){assert.notEqual(h.c.fruitSprites[i].img,h.images[0]);assert.equal(h.c.fruitSprites[i].img.width,theme.atlas.frames[i].width);}
});
test('atlas decode errors or incorrect dimensions keep every tile on safe placeholder',()=>{
 const h=loaderHarness();h.load();h.images[0].onerror();assert.ok(h.c.fruitSprites.every(r=>!r.ready));assert.equal(h.callbacks(),1);
 const d=loaderHarness();d.load();d.images[0].naturalWidth=100;d.images[0].onload();assert.ok(d.c.fruitSprites.every(r=>!r.ready));assert.equal(d.callbacks(),1);
});
test('partial cache failure does not leave a mixed old/new ready tile set',()=>{
 const h=loaderHarness({failCache:true});h.load();h.images[0].onload();assert.ok(h.c.fruitSprites.every(r=>!r.ready));assert.equal(h.callbacks(),1);
});
test('Canvas selection paints after opaque tile and ice overlay; goal pips use matching theme indices',()=>{
 const html=fs.readFileSync(path.join(root,'lumi.html'),'utf8');const drawOne=html.slice(html.indexOf('  function drawOne('),html.indexOf('  function drawIceCap('));
 assert.ok(drawOne.indexOf('selectionFrame')>drawOne.indexOf('drawFruit(g.type, s)'));assert.ok(drawOne.indexOf('selectionFrame')>drawOne.indexOf('if (g.ice) drawIceCap'));
 assert.match(html,/const pipType = p\.kind === 'straw' \? T_STRAW : \(p\.kind === 'melon' \? T_MELON/);
 assert.match(html,/ctx\.fillStyle = pipPal\.dk/);
});
