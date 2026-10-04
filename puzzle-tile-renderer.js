'use strict';
(function(root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.PuzzleTileRenderer = api;
})(typeof window !== 'undefined' ? window : globalThis, function() {
  function validAtlas(atlas, width, height) {
    if (!atlas || atlas.width !== width || atlas.height !== height || !Array.isArray(atlas.frames) || atlas.frames.length !== 6) return false;
    return atlas.frames.every(function(f, i) {
      if (![f.x,f.y,f.width,f.height,f.radius].every(Number.isFinite) || f.x<0 || f.y<0 || f.width<=0 || f.height<=0 || f.radius<0 || f.radius>Math.min(f.width,f.height)/2 || f.x+f.width>width || f.y+f.height>height) return false;
      return atlas.frames.every(function(g,j) {
        return i===j || f.x+f.width<=g.x || g.x+g.width<=f.x || f.y+f.height<=g.y || g.y+g.height<=f.y;
      });
    });
  }
  function roundedPath(ctx, x, y, width, height, radius) {
    const r=Math.max(0,Math.min(radius,width/2,height/2));
    ctx.beginPath(); ctx.moveTo(x+r,y);
    ctx.arcTo(x+width,y,x+width,y+height,r);
    ctx.arcTo(x+width,y+height,x,y+height,r);
    ctx.arcTo(x,y+height,x,y,r); ctx.arcTo(x,y,x+width,y,r); ctx.closePath();
  }
  function cacheFrame(createCanvas, image, frame) {
    // Mask at native resolution BEFORE small-size filtering; no white atlas field can bleed in.
    const canvas=createCanvas(); canvas.width=frame.width; canvas.height=frame.height;
    const ctx=canvas.getContext('2d');
    if (!ctx) throw new Error('Canvas 2D context unavailable');
    ctx.save();
    try {
      roundedPath(ctx,0,0,frame.width,frame.height,frame.radius); ctx.clip();
      ctx.drawImage(image,frame.x,frame.y,frame.width,frame.height,0,0,frame.width,frame.height);
    } finally { ctx.restore(); }
    return canvas;
  }
  function draw(ctx, image, frame, size) {
    // 0.8736 of a resting board cell; selected scale 1.06 still stays below one cell.
    const scale=(size*1.68)/Math.max(frame.width,frame.height);
    const width=frame.width*scale,height=frame.height*scale;
    ctx.save();
    try {
      roundedPath(ctx,-width/2,-height/2,width,height,frame.radius*scale); ctx.clip();
      ctx.drawImage(image,0,0,frame.width,frame.height,-width/2,-height/2,width,height);
    } finally { ctx.restore(); }
  }
  function selectionFrame(cell, x, y) {
    const width=Math.max(2,cell*.04),side=Math.max(1,cell-width-3);
    return {x:x-side/2,y:y-side/2,side,radius:side*.22,lineWidth:width};
  }
  return Object.freeze({validAtlas,roundedPath,cacheFrame,draw,selectionFrame});
});
