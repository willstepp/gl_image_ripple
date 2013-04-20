#import "RippleModel.h"

@interface RippleModel () {
    unsigned int screenWidth;
    unsigned int screenHeight;
    unsigned int poolWidth;
    unsigned int poolHeight;
    unsigned int touchRadius;
    
    unsigned int meshFactor;
    
    float texCoordFactorS;
    float texCoordOffsetS;
    float texCoordFactorT;
    float texCoordOffsetT;
    
    // ripple coefficients
    float *rippleCoeff;
    
    // ripple simulation buffers
    float *rippleSource;
    float *rippleDest;
    
    // data passed to GL
    GLfloat *rippleVertices;
    GLfloat *rippleTexCoords;
    GLushort *rippleIndicies;    
}

@end

@implementation RippleModel

- (void)initRippleMap
{
    // +2 for padding the border
    memset(rippleSource, 0, (poolWidth+2)*(poolHeight+2)*sizeof(float));
    memset(rippleDest, 0, (poolWidth+2)*(poolHeight+2)*sizeof(float));
}

- (void)initRippleCoeff
{
    for (int y=0; y<=2*touchRadius; y++)
    {
        for (int x=0; x<=2*touchRadius; x++)
        {        
            float distance = sqrt((x-touchRadius)*(x-touchRadius)+(y-touchRadius)*(y-touchRadius));
            
            if (distance <= touchRadius)
            {
                float factor = (distance/touchRadius);

                // goes from -512 -> 0
                rippleCoeff[y*(touchRadius*2+1)+x] = -(cos(factor*M_PI)+1.f) * 256.f;
            }
            else 
            {
                rippleCoeff[y*(touchRadius*2+1)+x] = 0.f;   
            }
        }
    }    
}

- (void)initMesh
{
    unsigned int index1 = 0;
    unsigned int index2 = 0;
    for (int i=0; i<poolHeight; i++)
    {
        for (int j=0; j<poolWidth; j++)
        {
            index1 = (i*poolWidth+j)*2+0;
            index2 = (i*poolWidth+j)*2+1;
            
            rippleVertices[index1] = -1.f + j*(2.f/(poolWidth-1));
            rippleVertices[index2] = 1.f - i*(2.f/(poolHeight-1));

            rippleTexCoords[index1] = (float)i/(poolHeight-1) * texCoordFactorS + texCoordOffsetS;
            rippleTexCoords[index2] = (1.f - (float)j/(poolWidth-1)) * texCoordFactorT + texCoordFactorT;
        }            
    }
    
    unsigned int index = 0;
    for (int i=0; i<poolHeight-1; i++)
    {
        for (int j=0; j<poolWidth; j++)
        {
            if (i%2 == 0)
            {
                // emit extra index to create degenerate triangle
                if (j == 0)
                {
                    rippleIndicies[index] = i*poolWidth+j;
                    index++;                    
                }
                
                rippleIndicies[index] = i*poolWidth+j;
                index++;
                rippleIndicies[index] = (i+1)*poolWidth+j;
                index++;
                
                // emit extra index to create degenerate triangle
                if (j == (poolWidth-1))
                {
                    rippleIndicies[index] = (i+1)*poolWidth+j;
                    index++;                    
                }
            }
            else
            {
                // emit extra index to create degenerate triangle
                if (j == 0)
                {
                    rippleIndicies[index] = (i+1)*poolWidth+j;
                    index++;
                }
                
                rippleIndicies[index] = (i+1)*poolWidth+j;
                index++;
                rippleIndicies[index] = i*poolWidth+j;
                index++;
                
                // emit extra index to create degenerate triangle
                if (j == (poolWidth-1))
                {
                    rippleIndicies[index] = i*poolWidth+j;
                    index++;
                }
            }
        }
    }
}

- (GLfloat *)getVertices
{
    return rippleVertices;
}

- (GLfloat *)getTexCoords
{
    return rippleTexCoords;
}

- (GLushort *)getIndices
{
    return rippleIndicies;
}

- (unsigned int)getVertexSize
{
    return poolWidth*poolHeight*2*sizeof(GLfloat);
}

- (unsigned int)getIndexSize
{
    return (poolHeight-1)*(poolWidth*2+2)*sizeof(GLushort);
}

- (unsigned int)getIndexCount
{
    return [self getIndexSize]/sizeof(*rippleIndicies);
}

- (void)freeBuffers
{
    free(rippleCoeff);
    
    free(rippleSource);
    free(rippleDest);
    
    free(rippleVertices);
    free(rippleTexCoords);
    free(rippleIndicies);    
}

- (id)initWithScreenWidth:(unsigned int)width
             screenHeight:(unsigned int)height
               meshFactor:(unsigned int)factor
              touchRadius:(unsigned int)radius
             textureWidth:(unsigned int)texWidth
            textureHeight:(unsigned int)texHeight
{
    self = [super init];
    
    if (self)
    {
        screenWidth = width;
        screenHeight = height;
        meshFactor = factor;
        poolWidth = width/meshFactor;
        poolHeight = height/meshFactor;
        touchRadius = radius;
        
        if ((float)screenHeight/screenWidth < (float)texWidth/texHeight)
        {            
            texCoordFactorS = (float)(texHeight*screenHeight)/(screenWidth*texWidth);            
            texCoordOffsetS = (1.f - texCoordFactorS)/2.f;
            
            texCoordFactorT = 1.f;
            texCoordOffsetT = 0.f;
        }
        else
        {
            texCoordFactorS = 1.f;
            texCoordOffsetS = 0.f;            
            
            texCoordFactorT = (float)(screenWidth*texWidth)/(texHeight*screenHeight);
            texCoordOffsetT = (1.f - texCoordFactorT)/2.f;
        }
        
        rippleCoeff = (float *)malloc((touchRadius*2+1)*(touchRadius*2+1)*sizeof(float));
        
        // +2 for padding the border
        rippleSource = (float *)malloc((poolWidth+2)*(poolHeight+2)*sizeof(float));
        rippleDest = (float *)malloc((poolWidth+2)*(poolHeight+2)*sizeof(float));
        
        rippleVertices = (GLfloat *)malloc(poolWidth*poolHeight*2*sizeof(GLfloat));
        rippleTexCoords = (GLfloat *)malloc(poolWidth*poolHeight*2*sizeof(GLfloat));
        rippleIndicies = (GLushort *)malloc((poolHeight-1)*(poolWidth*2+2)*sizeof(GLushort));
        
        if (!rippleCoeff || !rippleSource || !rippleDest || 
            !rippleVertices || !rippleTexCoords || !rippleIndicies)
        {
            [self freeBuffers];
            return nil;
        }
        
        [self initRippleMap];
        
        [self initRippleCoeff];
        
        [self initMesh];
    }
    
    return self;
}

- (void)runSimulation
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // first pass for simulation buffers...
    dispatch_apply(poolHeight, queue, ^(size_t y) {
        for (int x=0; x<poolWidth; x++)
        {
            // * - denotes current pixel
            //
            //       a 
            //     c * d
            //       b 
            
            // +1 to both x/y values because the border is padded
            float a = rippleSource[(y)*(poolWidth+2) + x+1];
            float b = rippleSource[(y+2)*(poolWidth+2) + x+1];
            float c = rippleSource[(y+1)*(poolWidth+2) + x];
            float d = rippleSource[(y+1)*(poolWidth+2) + x+2];
            
            float result = (a + b + c + d)/2.f - rippleDest[(y+1)*(poolWidth+2) + x+1];
            
            result -= result/32.f;
            
            rippleDest[(y+1)*(poolWidth+2) + x+1] = result;
        }            
    });
    
    // second pass for modifying texture coord
    dispatch_apply(poolHeight, queue, ^(size_t y) {
        for (int x=0; x<poolWidth; x++)
        {
            // * - denotes current pixel
            //
            //       a
            //     c * d
            //       b
            
            // +1 to both x/y values because the border is padded
            float a = rippleDest[(y)*(poolWidth+2) + x+1];
            float b = rippleDest[(y+2)*(poolWidth+2) + x+1];
            float c = rippleDest[(y+1)*(poolWidth+2) + x];
            float d = rippleDest[(y+1)*(poolWidth+2) + x+2];
            
            float s_offset = ((b - a) / 2048.f);
            float t_offset = ((c - d) / 2048.f);
            
            // clamp
            s_offset = (s_offset < -0.5f) ? -0.5f : s_offset;
            t_offset = (t_offset < -0.5f) ? -0.5f : t_offset;
            s_offset = (s_offset > 0.5f) ? 0.5f : s_offset;
            t_offset = (t_offset > 0.5f) ? 0.5f : t_offset;
            
            float s_tc = (float)y/(poolHeight-1) * texCoordFactorS + texCoordOffsetS;
            float t_tc = (1.f - (float)x/(poolWidth-1)) * texCoordFactorT + texCoordOffsetT;
            
            rippleTexCoords[(y*poolWidth+x)*2+0] = s_tc + s_offset;
            rippleTexCoords[(y*poolWidth+x)*2+1] = t_tc + t_offset;
        }
    });
    
    float *pTmp = rippleDest;
    rippleDest = rippleSource;
    rippleSource = pTmp;    
}

- (void)initiateRippleAtLocation:(CGPoint)location
{
    unsigned int xIndex = (unsigned int)((location.x / screenWidth) * poolWidth);
    unsigned int yIndex = (unsigned int)((location.y / screenHeight) * poolHeight);
    
    for (int y=(int)yIndex-(int)touchRadius; y<=(int)yIndex+(int)touchRadius; y++)
    {
        for (int x=(int)xIndex-(int)touchRadius; x<=(int)xIndex+(int)touchRadius; x++)
        {        
            if (x>=0 && x<poolWidth &&
                y>=0 && y<poolHeight)
            {
                // +1 to both x/y values because the border is padded
                rippleSource[(poolWidth+2)*(y+1)+x+1] += rippleCoeff[(y-(yIndex-touchRadius))*(touchRadius*2+1)+x-(xIndex-touchRadius)];   
            }
        }
    }    
}

- (void)dealloc
{
    [self freeBuffers];
}

@end
