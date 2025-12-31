import java.util.Map;
import com.hamoid.*;
import java.util.Dictionary;
import java.util.Enumeration;
import java.util.Hashtable;

String VIDEO_FILENAME = "typo_video_blah.mp4";
boolean SAVE_VIDEO = true;
boolean ONLY_SAVE_FINAL_PATH_FRAMES = false;
VideoExport videoExport;

int N = 400;
int BUCKET_MAX = 50;
int[] PRESET_PATH = null;

String[] strat_codes = {"RECT-1.0", "DIAM-1.0", "OS-0.6667"};
// first crew test {"RECT-3.0,NOM","RECT-3.0","RECT-1.0"};
// round crew test {"RECT-1.0","OCT-1.0","CIR-1.0"};
// diamond crew test {"RECT-1.0","CIR-1.0","DIAM-1.0"};
// spear test {"CIR-1.0","DIAM-1.0","OS-0.6667"};

color[] colors =
  //{color(128,0,200), color(90,150,0), color(230,0,70)};
  //{color(160,80,0), color(0,160,160), color(128,0,200)};
  //{color(160,80,0), color(128,0,200), color(255,128,0)};
{
  color(90, 150, 0), color(255, 128, 0), color(64, 0, 128)
};



int runs = 0;
int FRAMES_PER_RUN = 200;
int framesSinceLast = 0;
float prog = 0;
PImage crown;
Dictionary<String, String> names = new Hashtable<>();

Strategy[] strats = new Strategy[strat_codes.length];
int[] path_chosen;
float BASE_W = 1920;
float BASE_H = 1080;
float[] buttonBaseX = {1460, 1680, 1460, 1680, 1460};
float[] buttonBaseY = {840, 840, 920, 920, 1000};
float buttonBaseW = 200;
float buttonBaseH = 60;
Button[] buttons = {new Button(0, 1460, 840, 200, 60, "Slow"),
  new Button(1, 1680, 840, 200, 60, "Medium"),
  new Button(2, 1460, 920, 200, 60, "Fast"),
  new Button(3, 1680, 920, 200, 60, "Instant"),
  new Button(4, 1460, 1000, 200, 60, "I + Don't record")
};

void setup() {
  names.put("RECT-3.0,NOM", "Banger Tweet (No Maneuvers)");
  names.put("RECT-3.0", "Banger Tweet");
  names.put("RECT-1.0", "Square");
  names.put("RECT-1.0,NOM", "Square");
  names.put("RECT-1.2,JGD-4-2-0.73", "Wide Square (25% sus ends)");
  names.put("RECT-1.5,JGD-1-0-1.00", "Wide Square (Oops! All sus ends)");
  names.put("RECT-1.5,HOL-4-2-4", "Wide Square (With holes/tabs)");
  names.put("DIAM-1.0", "45-deg rotated square (\"Diamond\")");
  names.put("DIAM-1.0,NOM", "45-deg rotated square (\"Diamond\")");
  names.put("OS-0.6667", "Obsidian Spear");
  names.put("SOS-0.6667", "Sharpened Obsidian Spear");
  names.put("OCT-1.0", "Octagon");
  names.put("CIR-1.0", "Circle");

  crown = loadImage("crown.png");
  path_chosen = newPath();
  for (int s = 0; s < strat_codes.length; s++) {
    strats[s] = new Strategy(strat_codes[s], strats, s);
    strats[s].pathfind(path_chosen);
  }
  surface.setResizable(true);
  int defaultW = (int)(displayWidth*0.9);
  int defaultH = (int)(displayHeight*0.9);
  surface.setSize(defaultW, defaultH);
  surface.setLocation((displayWidth-defaultW)/2, (displayHeight-defaultH)/2);
  pixelDensity(1);
  if (SAVE_VIDEO) {
    videoExport = new VideoExport(this, VIDEO_FILENAME);
    videoExport.setFrameRate(60);
    videoExport.startMovie();
  }
}
void draw() {
  if (framesSinceLast >= FRAMES_PER_RUN) {
    setNewPaths();
    framesSinceLast = 0;
    runs++;
  }
  prog = (framesSinceLast+0.5)/FRAMES_PER_RUN*3;
  framesSinceLast++;

  background(255, 255, 200);
  for (int s = 0; s < strat_codes.length; s++) {
    strats[s].drawStrat(s*width/3, height*0.05, width/3, height*0.4);
  }
  drawGraph(80*(width/BASE_W), 700*(height/BASE_H), 1200*(width/BASE_W), 320*(height/BASE_H));
  drawButtons();
  if (ONLY_SAVE_FINAL_PATH_FRAMES) {
    if (framesSinceLast >= FRAMES_PER_RUN) {
      for (int s = 0; s < 5; s++) {
        videoExport.saveFrame();
      }
    }
  } else {
    if (SAVE_VIDEO && FRAMES_PER_RUN >= 3) {
      videoExport.saveFrame();
    }
  }
}
int getUnit(int m, float max_ratio) {
  int[] units = {1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000, 1000000};
  for (int u = 0; u < units.length; u++) {
    if (units[u] > m*max_ratio) {
      return units[u];
    }
  }
  return 1;
}

String commafy(int n) {
  String stri = n+"";
  String result = "";
  for (int i = 0; i < stri.length(); i++) {
    if (i >= 1 && (stri.length()-i)%3 == 0) {
      result += ",";
    }
    result += stri.charAt(i);
  }
  return result;
}

void drawGraph(float x, float y, float w, float h) {
  strokeWeight(2);
  stroke(128);
  fill(128);
  textAlign(CENTER);
  textSize(30);
  int horiz_unit = getUnit(BUCKET_MAX, 0.05);
  for (int b = 0; b < BUCKET_MAX; b+=horiz_unit) {
    float line_x = x+w*(float)b/BUCKET_MAX;
    line(line_x, y, line_x, y+h);
    text(b, line_x, y+h+30);
  }
  int max = 0;
  for (int s = 0; s < strat_codes.length; s++) {
    max = max(max, strats[s].getBucketMax());
  }
  int vert_unit = getUnit(max, 0.2);
  textAlign(RIGHT);
  for (int u = 0; u < max; u += vert_unit) {
    float line_y = y+h-h*((float)u/max);
    line(x, line_y, x+w, line_y);
    text(commafy(u), x-6, line_y+10);
  }

  for (int s = 0; s < strat_codes.length; s++) {
    stroke(colors[s]);
    for (int b = 0; b < BUCKET_MAX-1; b++) {
      float x1 = x+w*(float)b/BUCKET_MAX;
      float x2 = x+w*(float)(b+1)/BUCKET_MAX;
      float y1 = y+h-h*((float)strats[s].buckets[b]/max);
      float y2 = y+h-h*((float)strats[s].buckets[b+1]/max);
      strokeWeight(5);
      if (s < strat_codes.length-1 &&
        strats[s].buckets[b] == strats[s+1].buckets[b] &&
        strats[s].buckets[b+1] == strats[s+1].buckets[b+1]) {
        strokeWeight(10);
      }
      line(x1, y1, x2, y2);
    }
    strokeWeight(5);
    float avg = strats[s].data[0];
    float x_avg = x+w*avg/BUCKET_MAX;
    float y_avg = y+h-h*getFloatValue(strats[s].buckets, avg)/max;
    dottedLine(x_avg, y_avg, x_avg, y+h, 20, 1.61803*s);
  }

  textSize(40);
  fill(0);
  text("N = "+commafy(runs), x+w-10, y+40);
}
void dottedLine(float x1, float y1, float x2, float y2, float size, float offset) {
  float dist_ = dist(x1, y1, x2, y2);
  int pieces = ceil(dist_/size);
  for (int p = -2; p < pieces+2; p+=2) {

    float start_prog = min(max((p-offset%2.0)*size/dist_, 0), 1);
    float end_prog = min(max((p+1-offset%2.0)*size/dist_, 0), 1);
    float x_a = lerp(x1, x2, start_prog);
    float y_a = lerp(y1, y2, start_prog);
    float x_b = lerp(x1, x2, end_prog);
    float y_b = lerp(y1, y2, end_prog);
    line(x_a, y_a, x_b, y_b);
  }
}
float getFloatValue(int[] arr, float index) {
  int i = (int)index;
  float before = arr[min(max(i, 0), arr.length-1)];
  float after = arr[min(max(i+1, 0), arr.length-1)];
  return before + (after-before)*(index%1.0);
}
void drawButtons() {
  layoutButtons();
  for (int b = 0; b < buttons.length; b++) {
    buttons[b].drawButton();
  }
}
void layoutButtons() {
  float sx = width/BASE_W;
  float sy = height/BASE_H;
  for (int b = 0; b < buttons.length; b++) {
    buttons[b].x = buttonBaseX[b]*sx;
    buttons[b].y = buttonBaseY[b]*sy;
    buttons[b].w = buttonBaseW*sx;
    buttons[b].h = buttonBaseH*sy;
  }
}
void setNewPaths() {
  path_chosen = newPath();
  for (int s = 0; s < strat_codes.length; s++) {
    strats[s].pathfind(path_chosen);
  }
}
int[] ringAroundTheDiamond() {
  int C = 421;
  int R = 14;
  int runs_mod = runs%(R*8);
  int[] select = new int[R*4];
  for (int r = 0; r < R; r++) {
    select[r] = (r+1)*(r+1)-1;
    select[R*1+r] = C-(R-r)*(R-r)-1;
    select[R*2+r] = C-(r+1)*(r+1);
    select[R*3+r] = (R-r)*(R-r);
  }
  int[] s = {0, 0};
  if (runs_mod < R*2) {
    s[0] = R*3;
    s[1] = runs_mod;
  } else if (runs_mod < R*4) {
    s[0] = (R*3+runs_mod-R*2)%(R*4);
    s[1] = R*2;
  } else if (runs_mod < R*6) {
    s[0] = R*1;
    s[1] = (runs_mod-R*4)+R*2;
  } else if (runs_mod < R*8) {
    s[0] = (R*1+runs_mod-R*6)%(R*4);
    s[1] = 0;
  }

  int[] result = {select[s[0]], select[s[1]]};

  return result;
}

int[] newPath() {
  //return ringAroundTheDiamond();

  if (PRESET_PATH != null) {
    return PRESET_PATH;
  }
  int[] result = {0, 0};
  result[0] = (int)random(0, N);
  do {
    result[1] = (int)random(0, N);
  } while (result[1] == result[0]);
  return result;
}

void mousePressed() {
  for (int b = 0; b < buttons.length; b++) {
    if (buttons[b].isClicked(mouseX, mouseY)) {
      buttons[b].activate();
    }
  }
}
