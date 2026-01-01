import java.util.Map;
import com.hamoid.*;
import java.util.Dictionary;
import java.util.Enumeration;
import java.util.Hashtable;
import java.util.concurrent.*;

String VIDEO_FILENAME = "typo_video_blah.mp4";
boolean SAVE_VIDEO = true;
boolean ONLY_SAVE_FINAL_PATH_FRAMES = false;
VideoExport videoExport;

int N = 400;
int BUCKET_MAX = 50;
int[] PRESET_PATH = null;

String[] base_strat_codes = {"RECT-1.0", "DIAM-1.0", "OS-0.6667"};
String[] strat_codes = base_strat_codes.clone();
boolean evolveMode = false;
boolean evolvePaused = false;
int EVO_POP = 50;
int EVO_ELITE = 5;
int EVO_SAMPLES = 10000;
int EVO_POINTS = 6;
int evoGen = 0;
String[] evoPop;
float[] evoScore;
float[] evoStd;
String bestEvoCode = "";
float bestEvoScore = 999999;
float bestEvoStd = 0;
boolean SAVE_SOTA_IMAGE = true;
boolean saveSotaPending = false;
String sotaRunDir = "";
ExecutorService evoPool;
Future<float[]>[] evoFutures;
String[] evoEvalCodes;
int[][] evoEvalPaths;
boolean evoEvalRunning = false;
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
int cyclesPerFrame = 1;
PImage crown;
Dictionary<String, String> names = new Hashtable<>();

Strategy[] strats = new Strategy[strat_codes.length];
int[] path_chosen;
float BASE_W = 1920;
float BASE_H = 1080;
float[] buttonBaseX = {1460, 1680, 1460, 1680, 1460, 1680, 1460, 1680};
float[] buttonBaseY = {840, 840, 920, 920, 1000, 1000, 760, 760};
float buttonBaseW = 200;
float buttonBaseH = 60;
Button[] buttons = {new Button(0, 1460, 840, 200, 60, "Slow"),
  new Button(1, 1680, 840, 200, 60, "Medium"),
  new Button(2, 1460, 920, 200, 60, "Fast"),
  new Button(3, 1680, 920, 200, 60, "Instant"),
  new Button(4, 1460, 1000, 200, 60, "I + Don't record"),
  new Button(5, 1680, 1000, 200, 60, "Ludicrous"),
  new Button(6, 1460, 760, 200, 60, "Evolve"),
  new Button(7, 1680, 760, 200, 60, "Pause Evo")
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
  rebuildStrats(strat_codes);
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
  if (evolveMode && !evolvePaused) {
    evolveGeneration();
  }
  for (int c = 0; c < cyclesPerFrame; c++) {
    if (framesSinceLast >= FRAMES_PER_RUN) {
      setNewPaths();
      framesSinceLast = 0;
      runs++;
    }
    prog = (framesSinceLast+0.5)/FRAMES_PER_RUN*3;
    framesSinceLast++;
  }

  background(255, 255, 200);
  for (int s = 0; s < strat_codes.length; s++) {
    strats[s].drawStrat(s*width/3, height*0.05, width/3, height*0.4);
  }
  if (saveSotaPending) {
    saveSotaImage();
  }
  drawGraph(80*(width/BASE_W), 700*(height/BASE_H), 1200*(width/BASE_W), 320*(height/BASE_H));
  drawButtons();
  if (evolveMode) {
    fill(0);
    textAlign(CENTER);
    textSize(26);
    String label = "Evolve gen " + evoGen + " best avg " + nf(bestEvoScore, 0, 2);
    if (evolvePaused) {
      label += " (paused)";
    }
    float evoX = ((buttonBaseX[6] + buttonBaseX[7])*0.5 + buttonBaseW*0.5)*(width/BASE_W);
    float evoY = (buttonBaseY[6] - 20)*(height/BASE_H);
    text(label, evoX, evoY);
  }
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
void saveSotaImage() {
  saveSotaPending = false;
  if (sotaRunDir == null || sotaRunDir.length() == 0) {
    initSotaRunDir();
  }
  float gx = 0;
  float gy = height*0.05;
  float gw = width/3;
  float gh = height*0.4;
  float headerH = 40;
  float capY = max(0, gy-headerH);
  float capH = gh + (gy-capY);
  PImage snap = get((int)gx, (int)capY, (int)gw, (int)capH);
  String safeCode = sanitizeFilename(bestEvoCode);
  String filename = sotaRunDir + "/sota" + nf(evoGen, 4) + "-" + safeCode + ".png";
  snap.save(filename);
}
void initSotaRunDir() {
  String stamp = nf(year(), 4) + nf(month(), 2) + nf(day(), 2) + "-" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2);
  sotaRunDir = "sota_runs/run-" + stamp;
  File dir = new File(sketchPath(sotaRunDir));
  if (!dir.exists()) {
    dir.mkdirs();
  }
}
String sanitizeFilename(String s) {
  if (s == null || s.length() == 0) {
    return "unknown";
  }
  String out = "";
  for (int i = 0; i < s.length(); i++) {
    char c = s.charAt(i);
    if ((c >= 'a' && c <= 'z') ||
      (c >= 'A' && c <= 'Z') ||
      (c >= '0' && c <= '9') ||
      c == '-' || c == '_' ) {
      out += c;
    } else {
      out += "_";
    }
  }
  return out;
}
void rebuildStrats(String[] codes) {
  strat_codes = codes;
  strats = new Strategy[strat_codes.length];
  path_chosen = newPath();
  for (int s = 0; s < strat_codes.length; s++) {
    strats[s] = new Strategy(strat_codes[s], strats, s);
    strats[s].pathfind(path_chosen);
  }
}
void toggleEvolveMode() {
  evolveMode = !evolveMode;
  if (evolveMode) {
    evolvePaused = false;
    initEvolution();
  } else {
    if (evoFutures != null) {
      for (int i = 0; i < evoFutures.length; i++) {
        evoFutures[i].cancel(true);
      }
    }
    evoEvalRunning = false;
    evoFutures = null;
    evoEvalCodes = null;
    evoEvalPaths = null;
    rebuildStrats(base_strat_codes.clone());
  }
}
void toggleEvolvePause() {
  if (!evolveMode) {
    return;
  }
  evolvePaused = !evolvePaused;
}
void initEvolution() {
  evoGen = 0;
  bestEvoScore = 999999;
  bestEvoStd = 0;
  bestEvoCode = "";
  if (SAVE_SOTA_IMAGE) {
    initSotaRunDir();
  }
  evoEvalRunning = false;
  evoPop = new String[EVO_POP];
  evoScore = new float[EVO_POP];
  evoStd = new float[EVO_POP];
  int seedCount = min(base_strat_codes.length, EVO_POP);
  for (int i = 0; i < seedCount; i++) {
    evoPop[i] = base_strat_codes[i];
  }
  for (int i = seedCount; i < EVO_POP; i++) {
    evoPop[i] = randomFreeCode();
  }
}
void evolveGeneration() {
  if (evoPop == null || evoPop.length == 0) {
    initEvolution();
  }
  if (!evoEvalRunning) {
    startParallelEval();
    return;
  }
  if (!isEvalDone()) {
    return;
  }
  finishParallelEval();
}
void startParallelEval() {
  if (evoPool == null) {
    int threads = max(1, Runtime.getRuntime().availableProcessors()-1);
    evoPool = Executors.newFixedThreadPool(threads);
  }
  evoEvalPaths = makeEvalPaths(EVO_SAMPLES);
  evoEvalCodes = evoPop.clone();
  evoFutures = (Future<float[]>[]) new Future[evoEvalCodes.length];
  for (int i = 0; i < evoEvalCodes.length; i++) {
    final String code = evoEvalCodes[i];
    evoFutures[i] = evoPool.submit(new Callable<float[]>() {
      public float[] call() {
        return evaluateCode(code, evoEvalPaths);
      }
    }
    );
  }
  evoEvalRunning = true;
}
boolean isEvalDone() {
  if (evoFutures == null) {
    return false;
  }
  for (int i = 0; i < evoFutures.length; i++) {
    if (!evoFutures[i].isDone()) {
      return false;
    }
  }
  return true;
}
void finishParallelEval() {
  if (evoEvalCodes == null) {
    evoEvalRunning = false;
    return;
  }
  if (evoScore == null || evoScore.length != evoEvalCodes.length) {
    evoScore = new float[evoEvalCodes.length];
  }
  if (evoStd == null || evoStd.length != evoEvalCodes.length) {
    evoStd = new float[evoEvalCodes.length];
  }
  for (int i = 0; i < evoEvalCodes.length; i++) {
    try {
      float[] result = evoFutures[i].get();
      evoScore[i] = result[0];
      evoStd[i] = result[1];
    }
    catch (Exception e) {
      evoScore[i] = 999999;
      evoStd[i] = 0;
    }
  }
  int[] order = sortIndices(evoScore);
  int topCount = min(3, order.length);
  String[] topCodes = new String[topCount];
  int topIndex = 0;
  if (bestEvoCode != null && bestEvoCode.length() > 0) {
    topCodes[topIndex] = bestEvoCode;
    names.put(bestEvoCode, "SOTA avg "+nf(bestEvoScore, 0, 2)+", std "+nf(bestEvoStd, 0, 2));
    topIndex++;
  }
  for (int i = 0; i < order.length && topIndex < topCount; i++) {
    String code = evoEvalCodes[order[i]];
    if (bestEvoCode != null && bestEvoCode.equals(code)) {
      continue;
    }
    topCodes[topIndex] = code;
    names.put(code, "EVO #"+(topIndex+1)+" avg "+nf(evoScore[order[i]], 0, 2)+", std "+nf(evoStd[order[i]], 0, 2));
    topIndex++;
  }
  if (evoScore[order[0]] < bestEvoScore) {
    bestEvoScore = evoScore[order[0]];
    bestEvoStd = evoStd[order[0]];
    bestEvoCode = evoEvalCodes[order[0]];
    if (SAVE_SOTA_IMAGE) {
      saveSotaPending = true;
    }
  }
  rebuildStrats(topCodes);

  String[] next = new String[EVO_POP];
  for (int i = 0; i < EVO_POP; i++) {
    if (i < EVO_ELITE) {
      next[i] = evoEvalCodes[order[i]];
    } else if (i < EVO_ELITE + 2) {
      next[i] = randomFreeCode();
    } else {
      String parentA = evoEvalCodes[order[(int)random(EVO_ELITE)]];
      String parentB = evoEvalCodes[order[(int)random(EVO_ELITE)]];
      String child = crossoverCode(parentA, parentB);
      if (random(1) < 0.7) {
        child = mutateCode(child);
      }
      next[i] = child;
    }
  }
  evoPop = next;
  evoGen++;
  evoEvalRunning = false;
  evoFutures = null;
  evoEvalCodes = null;
  evoEvalPaths = null;
}
int[][] makeEvalPaths(int count) {
  int[][] result = new int[count][2];
  for (int i = 0; i < count; i++) {
    int a = (int)random(0, N);
    int b = a;
    while (b == a) {
      b = (int)random(0, N);
    }
    result[i][0] = a;
    result[i][1] = b;
  }
  return result;
}
float[] evaluateCode(String code, int[][] evalPaths) {
  Strategy tmp = new Strategy(code, new Strategy[1], 0);
  if (tmp.tiles.size() < N) {
    return new float[] {999999, 0};
  }
  for (int i = 0; i < evalPaths.length; i++) {
    tmp.pathfind(evalPaths[i]);
  }
  return new float[] {tmp.data[0], tmp.data[1]};
}
int[] sortIndices(float[] values) {
  int[] order = new int[values.length];
  for (int i = 0; i < values.length; i++) {
    order[i] = i;
  }
  for (int i = 0; i < values.length-1; i++) {
    int best = i;
    for (int j = i+1; j < values.length; j++) {
      if (values[order[j]] < values[order[best]]) {
        best = j;
      }
    }
    int tmp = order[i];
    order[i] = order[best];
    order[best] = tmp;
  }
  return order;
}
String randomFreeCode() {
  float aspect = random(0.6, 2.2);
  float[] left = new float[EVO_POINTS];
  float[] right = new float[EVO_POINTS];
  for (int i = 0; i < EVO_POINTS; i++) {
    left[i] = random(0.0, 0.5);
    right[i] = random(left[i]+0.2, 1.0);
  }
  return buildFreeCode(aspect, left, right);
}
String buildFreeCode(float aspect, float[] left, float[] right) {
  String code = "FREE-"+nf(aspect, 0, 3);
  for (int i = 0; i < left.length; i++) {
    code += "-"+nf(constrain(left[i], 0, 1), 0, 3);
  }
  for (int i = 0; i < right.length; i++) {
    code += "-"+nf(constrain(right[i], 0, 1), 0, 3);
  }
  return code;
}
FreeShape parseFree(String code) {
  String head = code.split(",")[0];
  String[] bits = head.split("-");
  if (bits.length < 6 || !bits[0].equals("FREE")) {
    return null;
  }
  int total = bits.length - 2;
  if (total % 2 != 0) {
    return null;
  }
  int k = total/2;
  float aspect = parseFloat(bits[1]);
  float[] left = new float[k];
  float[] right = new float[k];
  for (int i = 0; i < k; i++) {
    left[i] = parseFloat(bits[2+i]);
    right[i] = parseFloat(bits[2+k+i]);
  }
  return new FreeShape(aspect, left, right);
}
String mutateCode(String code) {
  FreeShape f = parseFree(code);
  if (f == null) {
    return randomFreeCode();
  }
  f.aspect = constrain(f.aspect + (float)randomGaussian()*0.15, 0.4, 3.0);
  for (int i = 0; i < f.left.length; i++) {
    if (random(1) < 0.9) {
      f.left[i] += (float)randomGaussian()*0.08;
    }
    if (random(1) < 0.9) {
      f.right[i] += (float)randomGaussian()*0.08;
    }
    f.left[i] = constrain(f.left[i], 0, 1);
    f.right[i] = constrain(f.right[i], 0, 1);
    if (f.right[i] < f.left[i] + 0.15) {
      f.right[i] = min(1, f.left[i] + 0.15);
    }
    if (f.left[i] > f.right[i] - 0.05) {
      f.left[i] = max(0, f.right[i] - 0.05);
    }
  }
  return buildFreeCode(f.aspect, f.left, f.right);
}
String crossoverCode(String a, String b) {
  FreeShape fa = parseFree(a);
  FreeShape fb = parseFree(b);
  if (fa == null || fb == null || fa.left.length != fb.left.length) {
    return randomFreeCode();
  }
  int k = fa.left.length;
  float[] left = new float[k];
  float[] right = new float[k];
  for (int i = 0; i < k; i++) {
    left[i] = (random(1) < 0.5) ? fa.left[i] : fb.left[i];
    right[i] = (random(1) < 0.5) ? fa.right[i] : fb.right[i];
    if (right[i] < left[i] + 0.15) {
      right[i] = min(1, left[i] + 0.15);
    }
  }
  float aspect = constrain((fa.aspect + fb.aspect)*0.5 + (float)randomGaussian()*0.05, 0.4, 3.0);
  return buildFreeCode(aspect, left, right);
}
class FreeShape {
  float aspect;
  float[] left;
  float[] right;
  FreeShape(float aspect_, float[] left_, float[] right_) {
    aspect = aspect_;
    left = left_;
    right = right_;
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
