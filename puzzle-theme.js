'use strict';
// Approved original 3x2 bitmap is unchanged. Frames and clipping are runtime code.
// Logical types 0..5 retain original levels, matches, rewards and save semantics.
(function (root) {
  const palette = [
    {hi:'#ff9d9d',mid:'#ef3343',dk:'#a40f27',edge:'#bf1c32',glow:'rgba(239,51,67,.55)'},
    {hi:'#fff59a',mid:'#f6c91a',dk:'#aa7105',edge:'#c38b07',glow:'rgba(246,201,26,.55)'},
    {hi:'#ceff9b',mid:'#56c845',dk:'#16873a',edge:'#238e3c',glow:'rgba(86,200,69,.55)'},
    {hi:'#a1dfff',mid:'#278bea',dk:'#1553a4',edge:'#2162b6',glow:'rgba(39,139,234,.55)'},
    {hi:'#dfb4ff',mid:'#a655e6',dk:'#6424a1',edge:'#8138be',glow:'rgba(166,85,230,.55)'},
    {hi:'#ffe0a1',mid:'#ff912c',dk:'#b95013',edge:'#d16b18',glow:'rgba(255,145,44,.55)'},
  ].map(Object.freeze);
  const frames = [
    {x:78,y:54,width:444,height:435,radius:100},
    {x:543,y:52,width:444,height:437,radius:100},
    {x:1011,y:52,width:445,height:436,radius:100},
    {x:78,y:509,width:443,height:434,radius:100},
    {x:543,y:510,width:443,height:434,radius:100},
    {x:1011,y:508,width:444,height:436,radius:100},
  ].map(Object.freeze);
  root.PuzzleTileTheme = Object.freeze({
    id:'colored-cats-v4', boardTitle:'고양이와 커피',
    boardSubtitle:'고양이 퍼즐 · 레벨 선택',
    instruction:'같은 색 고양이를 세 마리 이상 맞춰 보세요',
    labels:Object.freeze(['빨강 고양이','노랑 고양이','초록 고양이','파랑 고양이','보라 고양이','주황 고양이']),
    palette:Object.freeze(palette), images:null,
    atlas:Object.freeze({src:root.PuzzleCatAtlasData || 'sprites/cats/colored-cat-tokens-v4.png',
      sourcePath:'sprites/cats/colored-cat-tokens-v4.png', width:1536,height:1024,
      frames:Object.freeze(frames)}),
  });
})(typeof window !== 'undefined' ? window : globalThis);
