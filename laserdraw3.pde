import oscP5.*;
import netP5.*;
import java.util.zip.Deflater;

OscP5 oscP5;
NetAddress network;

ArrayList<ArrayList> paths = new ArrayList();

float[] pointsXYRGB;

Point closestPoint = new Point(0,0);
Point createdPoint; // reference to the most recently created point
Point draggedPoint;


Point mousePos = new Point(mouseX, mouseY);
boolean continuePath = false;
boolean canCreatePoint = true;
boolean dragging = false;

int pointSelectRadius = 40;
boolean snapToGrid = true;
float gridScale = 20;

int beamStrokeWeight = 6;
int blankStrokeWeight = 1;
boolean drawBlanks = true;

boolean oscEnabled = true;

int currentColorIdx = 1;
int[][] colors = {
  {  0,   0,   0},
  {255, 255, 255},
  {255,   0,   0},
  {255, 255,   0},
  {  0, 255,   0},
  {  0, 255, 255},
  {  0,   0, 255},
  {255,   0, 255}
};


void setup() {
  size(1024,1024);
  frameRate(30);
  oscP5 = new OscP5(this,12000);
  network = new NetAddress("nuc",12000);
  blendMode(ADD);
}



void draw() {
  background(0);
  
  if (snapToGrid) {
    drawGrid();
    drawGridCursor();
  }

  drawColorIndicator(30, 30, 30);
  
  pushMatrix();
  translate(width/2, height/2);

  // draw closest point to cursor
  if (paths.size() > 0 && paths.get(0).size() > 0 
  && closestPoint.dist(new Point(mousePos.x, mousePos.y)) < pointSelectRadius) {
    int[] col = closestPoint.rgb;
    fill(col[0], col[1], col[2]);
    noStroke();
    ellipse(closestPoint.x, closestPoint.y, 20, 20);
  }
  
  // draw next line preview
  if (continuePath && createdPoint != null) {
    int[] col = colors[currentColorIdx];
    stroke(col[0], col[1], col[2]);
    strokeWeight(1);
    float cx = mouseX-width/2;
    float cy = mouseY-width/2;
    if (snapToGrid) {
      cx = snapToGrid(cx);
      cy = snapToGrid(cy);
    }
    
    line(cx, cy, createdPoint.x, createdPoint.y);
  }
  
  // draw last added point
  if (createdPoint != null) {
    int[] col = createdPoint.rgb;
    fill(col[0], col[1], col[2]);
    noStroke();
    ellipse(createdPoint.x, createdPoint.y, 10, 10);
  }
  
  drawBeamPath();
  popMatrix();
  //sendXYRGB();
}


void mouseMoved() {
  //println("moved");
  mousePos.x = mouseX-width/2;
  mousePos.y = mouseY-height/2;
  if (paths.size() > 0) {
    int[] idxs = findclosestpoint(mousePos);
    closestPoint = (Point)paths.get(idxs[0]).get(idxs[1]);
  }

  updatePointsXYRGB();
  sendXYRGB();
}


void mouseDragged() {
  //println("dragged");
  mousePos.x = mouseX-width/2;
  mousePos.y = mouseY-height/2;
  
  float actualSelectRadius = pointSelectRadius;
  if (snapToGrid) {
    actualSelectRadius = max(pointSelectRadius, width/gridScale*2);
  }
   
  if (paths.size() > 0) {
    int[] idxs = findclosestpoint(mousePos);
    closestPoint = (Point)paths.get(idxs[0]).get(idxs[1]);
  }
  if (mouseButton == CENTER
  && closestPoint.dist(new Point(mousePos.x, mousePos.y)) < actualSelectRadius) {
    
    if(snapToGrid) {
      closestPoint.x = snapToGrid(mousePos.x);
      closestPoint.y = snapToGrid(mousePos.y);
    }
    else {
      closestPoint.x = mousePos.x;
      closestPoint.y = mousePos.y;    
    }
    //updatePointsXYRGB();
    //sendXYRGB();
  }

}


void mousePressed() {
  
  if (mouseButton == LEFT) {
    int[] col = colors[currentColorIdx];
    Point newPoint = new Point(mousePos.x, mousePos.y, col);
    if (snapToGrid) {
      newPoint.x = snapToGrid(newPoint.x);
      newPoint.y = snapToGrid(newPoint.y);
    }

    if (paths.size() == 0) {
      paths.add(new ArrayList<Point>());
      paths.get(0).add(newPoint);
    }
    else {
      if (!continuePath) {
        paths.add(new ArrayList<Point>());
      }
      paths.get(paths.size()-1).add(newPoint);
    }
    closestPoint = newPoint;
    createdPoint = newPoint;
    canCreatePoint = false;
    continuePath = true;
    updatePointsXYRGB();
    println("numpoints:" + pointsXYRGB.length);
    sendXYRGB();
  }
  else if (mouseButton == RIGHT) {
    continuePath = false;
  }
}

void mouseReleased() {
  canCreatePoint = true;
  
  if (mouseButton == RIGHT && continuePath) {
    
  }
}

void keyTyped() {
  //println("key: " + key);
  switch(key) {
    case 'u':
      undo();
      break;
      
    case 'c':
      paths = new ArrayList();
      continuePath = false;
      createdPoint = null;
      break;
      
    case 'b':
      drawBlanks = !drawBlanks;
      break;

    case 'g':
      snapToGrid = ! snapToGrid;
      break;

    case '=':
      if (gridScale > 2) {
        gridScale-=2;
      }
      println("grid: " + gridScale);
      break;

    case '-':
      if (gridScale < 32) {
        gridScale+=2;
      }
      println("grid: " + gridScale);
      break;

    case '0':
      currentColorIdx = 0;
      break;
    case '1':
      currentColorIdx = 1;
      break;
    case '2':
      currentColorIdx = 2;
      break;
    case '3':
      currentColorIdx = 3;
      break;
    case '4':
      currentColorIdx = 4;
      break;
    case '5':
      currentColorIdx = 5;
      break;
    case '6':
      currentColorIdx = 6;
      break;
    case '7':
      currentColorIdx = 7;
      break;
  }
}


void drawGrid() {
  float dim = width / gridScale;
  stroke(48);
  strokeWeight(1);
  for (int y=0; y < dim; y++) {
    float x1 = 0;
    float y1 = y*dim;
    float x2 = width;
    float y2 = y*dim;
    line(x1, y1, x2, y2);
  }
  for (int x=0; x < dim; x++) {
    float x1 = x*dim;
    float y1 = 0;
    float x2 = x*dim;
    float y2 = height;
    line(x1, y1, x2, y2);
  }
}

void drawGridCursor() {
  float x = snapToGrid(mouseX);
  float y = snapToGrid(mouseY);
  stroke(255);
  strokeWeight(2);
  ellipse(x, y, 5, 5);
}

float snapToGrid(float x) {
  float xn = x / width;
  xn *= gridScale;
  xn = Math.round(xn);
  xn /= gridScale;
  xn *= width;
  return xn;
}

void drawBeamPath() {
  Point v1 = null, v2 = null;
  int pidx, vidx;
  for(pidx = 0; pidx < paths.size(); pidx++) {
    strokeWeight(beamStrokeWeight);

    ArrayList path = paths.get(pidx);
    for (vidx = 0; vidx < path.size()-1; vidx++) {
      v1 = (Point)path.get(vidx);
      v2 = (Point)path.get(vidx+1);
      stroke(v1.rgb[0], v1.rgb[1], v1.rgb[2], 128);
      line(v1.x, v1.y, v2.x, v2.y);
    }
    
    // draw blank line to join paths
    if (pidx < paths.size()-1 && drawBlanks) {
      ArrayList nextpath = paths.get(pidx+1);
      if (nextpath.size() > 0) {
        Point nextpoint = (Point)nextpath.get(0);
        strokeWeight(blankStrokeWeight);
        stroke(64,64,64);
        line(v2.x, v2.y, nextpoint.x, nextpoint.y);
      }
    }
    
  }
  
  // draw blank line from last point to first point
  if (paths.size() > 0 && drawBlanks) {
    ArrayList firstpath = paths.get(0);
    if (firstpath.size() > 0) {
      Point first = (Point)firstpath.get(0);
      ArrayList lastpath = paths.get(paths.size()-1);
      Point last = (Point)lastpath.get(lastpath.size()-1);
        strokeWeight(blankStrokeWeight);
        stroke(64,64,64);
        line(last.x, last.y, first.x, first.y);      
    }
  }
  
}

void drawColorIndicator(int x, int y, int rad) {
  int[] col = colors[currentColorIdx];
  if (currentColorIdx == 0) {
    stroke(64,64,64);
  }
  else {
    noStroke();
  }
  fill(col[0], col[1], col[2]);
  ellipse(x, y, rad, rad);
}


void updatePointsXYRGB() {
  int numpoints = getpointcount(paths);
  println("points:" + numpoints);
  int cursordwell = 8;
  pointsXYRGB = new float[numpoints*5 + (paths.size()*5 *2) + cursordwell*5];
  
  int idx = 0;
  Point p = null;
  for(int pidx = 0; pidx < paths.size(); pidx++) {
    ArrayList path = paths.get(pidx);
    // insert a blank point at the start of each path
    p = (Point)path.get(0);
    if (p != null) {
      pointsXYRGB[idx+0] = p.x / width*2 * 2047;
      pointsXYRGB[idx+1] = p.y / width*2 * 2047;
      pointsXYRGB[idx+2] = 0;
      pointsXYRGB[idx+3] = 0;
      pointsXYRGB[idx+4] = 0;
      idx+=5;
    }
    for (int vidx = 0; vidx < path.size(); vidx++) {
      p = (Point)path.get(vidx);
      pointsXYRGB[idx+0] = p.x / width*2 * 2047;
      pointsXYRGB[idx+1] = p.y / width*2 * 2047;
      pointsXYRGB[idx+2] = p.rgb[0];
      pointsXYRGB[idx+3] = p.rgb[1];
      pointsXYRGB[idx+4] = p.rgb[2];
      idx+=5;
    }
    // insert a blank point at the end of each path
    if (p != null) {
      pointsXYRGB[idx+0] = p.x / width*2 * 2047;
      pointsXYRGB[idx+1] = p.y / width*2 * 2047;
      pointsXYRGB[idx+2] = 0;
      pointsXYRGB[idx+3] = 0;
      pointsXYRGB[idx+4] = 0;
      idx+=5;
    }
  }

  float mx = mousePos.x*4; //mouseX / width/2.0 * 2047;
  float my = mousePos.y*4; //mouseY / height/2.0 * 2047;
  println("MOUSE ", mx, my);
  for (int i=0; i < cursordwell; i++) {
    pointsXYRGB[idx+0] = mx;
    pointsXYRGB[idx+1] = my;
    if (i == 0 || i == cursordwell-1) {
      pointsXYRGB[idx+2] = 0;
      pointsXYRGB[idx+3] = 0;
      pointsXYRGB[idx+4] = 0;
    }
    else {
      pointsXYRGB[idx+2] = colors[currentColorIdx][0];
      pointsXYRGB[idx+3] = colors[currentColorIdx][1];
      pointsXYRGB[idx+4] = colors[currentColorIdx][2];
    }
    idx += 5;
  }

}


void sendXYRGB() {
  if (! oscEnabled) {
    return;
  }
  int numpoints = pointsXYRGB.length / 5;
  if (numpoints == 0) {
    return;
  }
  byte[] packedData = new byte[numpoints * 7]; // 7 bytes for each point

  for (int i = 0; i < numpoints; i++) {
    int pidx = i * 5;
    int offset = i * 7;
    int x = floor((0.5 + 0.5 * (pointsXYRGB[pidx+0]*-1 / 2047)) * 65535);
    int y = floor((0.5 + 0.5 * (pointsXYRGB[pidx+1] / 2047)) * 65535);
    int r = floor(pointsXYRGB[pidx+2]);
    int g = floor(pointsXYRGB[pidx+3]);
    int b = floor(pointsXYRGB[pidx+4]);

    packUInt16(packedData, offset + 0, x);
    packUInt16(packedData, offset + 2, y);
    packUInt8(packedData, offset + 4, r);
    packUInt8(packedData, offset + 5, g);
    packUInt8(packedData, offset + 6, b);
  }

  Deflater deflater = new Deflater();
  deflater.setInput(packedData);
  deflater.finish();
  byte[] compressedData = new byte[packedData.length];
  int compressedDataLength = deflater.deflate(compressedData);

  OscMessage msg = new OscMessage("/f");
  msg.add(compressedData);
  oscP5.send(msg, network);
}

void packUInt16(byte[] bytes, int offset, int value) {
  bytes[offset] = (byte) (value & 0xFF);
  bytes[offset + 1] = (byte) ((value >> 8) & 0xFF);
}

void packUInt8(byte[] bytes, int offset, int value) {
  bytes[offset] = (byte) (value & 0xFF);
}
  




// Find [pathidx, pointindex, distance] of closest point to p
int[] findclosestpoint(Point p) {
  float closestdist = Float.MAX_VALUE;
  int[] ret = new int[2];
  for(int pidx = 0; pidx < paths.size(); pidx++) {
    ArrayList path = paths.get(pidx);
    for (int vidx = 0; vidx < path.size(); vidx++) {
      Point test = (Point)path.get(vidx);
      float dist = p.dist(test);
      if (dist < closestdist) {
        closestdist = dist;
        ret[0] = pidx;
        ret[1] = vidx;
      }
    }
  }
  return ret;
}


void undo() {
  if (paths.size() == 0) {
    return;
  }
  int pathidx = paths.size() - 1;
  ArrayList path = paths.get(pathidx);
  if (path.size() > 0) {
    int pointidx = path.size() - 1;
    path.remove(pointidx);
    if (path.size() == 0) {
      paths.remove(pathidx);
    }
  }
  
  if (paths.size() > 0) {
    path = paths.get(paths.size()-1);
    createdPoint = (Point)path.get(path.size()-1);
  }
  else {
    createdPoint = null;
    continuePath = false;
  }
  
}

int getpointcount(ArrayList paths) {
  int count = 0;
  for (int i = 0; i < paths.size(); i++) {
    count += ((ArrayList)paths.get(i)).size();
  }
  return count;
}

float cosinelerp(float y1,float y2, float mu) {
   float mu2 = (1.0-cos(mu*PI))* 0.5;
   return(y1*(1.0-mu2)+y2*mu2);
}


class Point {
  float x;
  float y;
  int[] rgb;
  
  public Point(float x, float y, int[] rgb) {
    this.x = x;
    this.y = y;
    this.rgb = rgb;
  }

  public Point(float x, float y) {
    this.x = x;
    this.y = y;
    this.rgb = new int[3];
    rgb[0] = rgb[1] = rgb[2] = 255;
  }
  
  public float dist(Point p) {
    float dx = x-p.x;
    float dy = y-p.y;
    return (float)Math.sqrt(dx*dx+dy*dy);
  }
  
  public String toString() {
    return "[" + x + " " + y + "] "
         + "[c: " + this.rgb + "]"; 
  
  }
}
