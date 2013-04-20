#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>

@interface RippleModel : NSObject

- (GLfloat *)getVertices;
- (GLfloat *)getTexCoords;
- (GLushort *)getIndices;
- (unsigned int)getVertexSize;
- (unsigned int)getIndexSize;
- (unsigned int)getIndexCount;

- (id)initWithScreenWidth:(unsigned int)width
             screenHeight:(unsigned int)height
               meshFactor:(unsigned int)factor
              touchRadius:(unsigned int)radius
             textureWidth:(unsigned int)texWidth
            textureHeight:(unsigned int)texHeight;

- (void)runSimulation;

- (void)initiateRippleAtLocation:(CGPoint)location;

@end
