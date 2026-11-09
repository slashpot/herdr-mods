ObjC.import('AppKit');
function run(argv) {
  const [src, out, x, y, w, h] = argv;
  const rep = $.NSBitmapImageRep.imageRepWithData($.NSData.dataWithContentsOfFile(src));
  const cg = rep.CGImage;
  const sub = $.CGImageCreateWithImageInRect(cg, $.CGRectMake(+x, +y, +w, +h));
  const outRep = $.NSBitmapImageRep.alloc.initWithCGImage(sub);
  outRep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $({})).writeToFileAtomically(out, true);
  return `${outRep.pixelsWide}x${outRep.pixelsHigh}`;
}
