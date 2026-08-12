export const MAX_IMAGE_BYTES=3*1024*1024;
export function hasAllowedImageSignature(bytes:Uint8Array){const jpeg=bytes[0]===0xff&&bytes[1]===0xd8&&bytes[2]===0xff;const png=bytes[0]===0x89&&bytes[1]===0x50&&bytes[2]===0x4e&&bytes[3]===0x47&&bytes[4]===0x0d&&bytes[5]===0x0a&&bytes[6]===0x1a&&bytes[7]===0x0a;const webp=String.fromCharCode(...bytes.slice(0,4))==="RIFF"&&String.fromCharCode(...bytes.slice(8,12))==="WEBP";return jpeg||png||webp}
export function validateImageInput(bytes:Uint8Array,size=bytes.byteLength){return size>0&&size<=MAX_IMAGE_BYTES&&hasAllowedImageSignature(bytes)}
