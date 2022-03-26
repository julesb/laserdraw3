import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress network;

ArrayList<ArrayList> paths = new ArrayList();

float[] pointsX;
float[] pointsY;  
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
float gridScale = 100;

int beamStrokeWeight = 6;
int blankStrokeWeight = 1;
boolean drawBlanks = true;


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
  network = new NetAddress("127.0.0.1",12000);
  blendMode(ADD);
}



void draw() {
  background(0);
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
    line(mouseX-width/2, mouseY-height/2, createdPoint.x, createdPoint.y);
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
  drawColorIndicator(30, 30, 30);
}


void mouseMoved() {
  //println("moved");
  mousePos.x = mouseX-width/2;
  mousePos.y = mouseY-height/2;
  if (paths.size() > 0) {
    int[] idxs = findclosestpoint(mousePos);
    closestPoint = (Point)paths.get(idxs[0]).get(idxs[1]);
  }
}


void mouseDragged() {
  //println("dragged");
  mousePos.x = mouseX-width/2;
  mousePos.y = mouseY-height/2;
   
   
  if (paths.size() > 0) {
    int[] idxs = findclosestpoint(mousePos);
    closestPoint = (Point)paths.get(idxs[0]).get(idxs[1]);
  }
  if (mouseButton == CENTER
  && closestPoint.dist(new Point(mousePos.x, mousePos.y)) < pointSelectRadius) {
    closestPoint.x = mousePos.x;
    closestPoint.y = mousePos.y;
    updatePointsXYRGB();
    sendXYRGB();
  }

}


void mousePressed() {
  
  if (mouseButton == LEFT) {
    int[] col = colors[currentColorIdx];
    Point newPoint = new Point(mousePos.x, mousePos.y, col);

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
    
    // draw blank line
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
  pointsXYRGB = new float[numpoints*5 + paths.size()*5];
  
  int idx = 0;
  Point p = null;
  for(int pidx = 0; pidx < paths.size(); pidx++) {
    ArrayList path = paths.get(pidx);
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
}


void sendXYRGB() {
  if (pointsXYRGB != null && pointsXYRGB.length > 0) {
    println("sending " + pointsXYRGB.length);
    OscMessage pointsxMessage = new OscMessage("/xyrgb");
    pointsxMessage.add(pointsXYRGB);
    oscP5.send(pointsxMessage, network);
  }
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
