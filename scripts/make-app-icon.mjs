// Render the existing code-defined two-stone brand; no external images or fonts.
import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';
const size = 1024;
const pixels = Buffer.alloc((size * 3 + 1) * size);
const mix = (a, b, t) => a.map((v, i) => Math.round(v * (1-t) + b[i] * t));
function circle(base, x, y, cx, cy, radius, color) {
  const distance = Math.hypot(x-cx, y-cy);
  const shade = Math.exp(-Math.max(0, Math.hypot(x-cx-2,y-cy-12)-radius)/8) * .12;
  if (distance > radius) return mix(base,[24,36,27],shade);
  const coverage = Math.min(1, radius-distance);
  const lit = Math.max(0, 1-Math.hypot(x-cx+radius*.3,y-cy+radius*.35)/(radius*1.4));
  return mix(base,mix(color,[255,255,250],lit*(color[0]<100 ? .09 : .35)),coverage);
}
for (let y=0;y<size;y++) {
  for (let x=0;x<size;x++) {
    let rgb=[237,240,224];
    const line = [184,348,512,676,840].some(p=>Math.abs(x-p)<1.4 || Math.abs(y-p)<1.4);
    if (line && x>132 && x<892 && y>132 && y<892) rgb=mix(rgb,[122,145,105],.16);
    rgb=circle(rgb,x,y,420,419,210,[46,74,59]);
    rgb=circle(rgb,x,y,614,618,198,[246,246,237]);
    const offset=y*(size*3+1)+1+x*3;
    for(let c=0;c<3;c++) pixels[offset+c]=rgb[c];
  }
}
const crcTable=Array.from({length:256},(_,n)=>{let c=n;for(let j=0;j<8;j++)c=(c&1)?0xedb88320^(c>>>1):c>>>1;return c>>>0;});
const crc32=b=>{let c=0xffffffff;for(const byte of b)c=crcTable[(c^byte)&255]^(c>>>8);return(c^0xffffffff)>>>0;};
const chunk=(type,data)=>{const name=Buffer.from(type),head=Buffer.alloc(4),crc=Buffer.alloc(4);head.writeUInt32BE(data.length);crc.writeUInt32BE(crc32(Buffer.concat([name,data])));return Buffer.concat([head,name,data,crc]);};
const header=Buffer.alloc(13);header.writeUInt32BE(size,0);header.writeUInt32BE(size,4);header[8]=8;header[9]=2;
writeFileSync(new URL('../ios/GoKit/Assets.xcassets/AppIcon.appiconset/AppIcon.png',import.meta.url),Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',deflateSync(pixels)),chunk('IEND',Buffer.alloc(0))]));
console.log('Created 1024×1024 RGB AppIcon.png');
