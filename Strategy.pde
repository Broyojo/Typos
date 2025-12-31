class Strategy {
  String s;
  int id;
  ArrayList<Tile> tiles;
  int tileW, tileH;
  Tile cursor_curr;
  Tile cursor_next;
  ArrayList<Tile> path;
  int strat_max_steps;
  int[][] dires = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};
  Strategy[] array;
  float[] data = {0, 0};
  int[] buckets;

  public Strategy(String s_, Strategy[] array_, int id_) {
    id = id_;
    s = s_;
    array = array_;
    tileW = 0;
    tileH = 0;
    tiles = new ArrayList<Tile>(0);
    buckets = new int[BUCKET_MAX];
    for (int b = 0; b < BUCKET_MAX; b++) {
      buckets[b] = 0;
    }
    int[] dims = getMinimumDims();
    int W = dims[0];
    int H = dims[1];

    Tile[][] map = clearMap(s, W, H);
    for (int x = 0; x < W; x++) {
      for (int y = 0; y < H; y++) {
        Tile thisTile = map[x][y];
        if (thisTile == null) {
          continue;
        }
        for (int dire = 0; dire < 4; dire++) {
          int dx = x+dires[dire][0];
          int dy = y+dires[dire][1];
          if (inBounds(dx, dy, W, H) && map[dx][dy] != null) {
            thisTile.leadTo[dire] = map[dx][dy];
          }
        }
      }
    }
    if (noManeuvers()) { // naive strats that don't loop over
      return;
    }
    // left-right loopover
    for (int n = 0; n < tiles.size()-1; n++) {
      Tile tile1 = tiles.get(n);
      Tile tile2 = tiles.get(n+1);
      float y1 = tile1.y;
      float y2 = tile2.y;
      //if (y1 != y2) {
      tile1.leadTo[1] = tile2;
      tile2.leadTo[0] = tile1;
      //}
    }
    // top-bottom clip to the extremes
    for (int x = 0; x < W; x++) {
      Tile topTile = map[x][0];
      if (topTile != null && topTile.n >= 1) {
        topTile.leadTo[2] = tiles.get(0);
      }
      Tile bottomTile = map[x][H-1];
      if (bottomTile != null && bottomTile.n < tiles.size()-1) {
        bottomTile.leadTo[3] = tiles.get(tiles.size()-1);
      }
    }
    // up-down into a gap
    for (int x = 0; x < W; x++) {
      for (int y = 0; y < H; y++) {
        Tile thisTile = map[x][y];
        if (thisTile == null) {
          continue;
        }
        if (y >= 1 && map[x][y-1] == null) {
          int dx = findClosestHorizontalValid(map, x, y-1, W, H);
          if (dx >= 0) {
            thisTile.leadTo[2] = map[dx][y-1];
          }
        }
        if (y < H-1 && map[x][y+1] == null) {
          int dx = findClosestHorizontalValid(map, x, y+1, W, H);
          if (dx >= 0) {
            thisTile.leadTo[3] = map[dx][y+1];
          }
        }
      }
    }
  }

  boolean noManeuvers() {
    String[] parts = s.split(",");
    for (int p = 0; p < parts.length; p++) {
      if (parts[p].equals("NOM")) {
        return true;
      }
    }
    return false;
  }

  int getWidthFromHeight(int h) {
    String[] parts = s.split(",");
    float aspect_ratio = Float.parseFloat(parts[0].split("-")[1]);
    String shapeType = parts[0].split("-")[0];
    if (shapeType.equals("OS") || shapeType.equals("SOS")) {
      return round(aspect_ratio*h*h);
    }
    return round(aspect_ratio*h);
  }

  int[] getMinimumDims() {
    int H = getMinimumSize();
    int[] result = {getWidthFromHeight(H), H};
    return result;
  }
  int getMinimumSize() {
    for (int a = 0; a < N; a++) {
      int count = 0;
      int W = getWidthFromHeight(a);
      int H = a;
      for (int x = 0; x < W; x++) {
        for (int y = 0; y < H; y++) {
          if (valid(s, x, y, W, H)) {
            count++;
          }
        }
      }
      if (count >= N) {
        return a;
      }
    }
    return -1;
  }

  int getBucketMax() {
    int best = 0;
    for (int b = 0; b < BUCKET_MAX; b++) {
      if (buckets[b] > best) {
        best = buckets[b];
      }
    }
    return best;
  }

  int findClosestHorizontalValid(Tile[][] map, int x, int y, int W, int H) {
    for (int dist = 1; dist < H; dist++) {
      for (int sign = -1; sign <= 1; sign += 2) {
        int dx = x+dist*sign;
        if (inBounds(dx, y, W, H) && map[dx][y] != null) {
          return dx;
        }
      }
    }
    return -1;
  }

  boolean shapeValid(String shape, int x, int y, int w, int h) {
    float EPS = 0.00000001;
    if (shape.equals("RECT")) {
      return true;
    } else if (shape.equals("DIAM")) {
      int n = (w-1)/2;
      int taxicab_dist = abs(x-n)+abs(y-n);
      return (taxicab_dist <= n);
    } else if (shape.equals("OS")) {
      return ((float)x/w < (1.0-(float)y/h)+EPS);
    } else if (shape.equals("SOS")) {
      return ((float)x/w < pow(1.0-(float)y/h, 2)+EPS);
    } else if (shape.equals("OCT")) {
      int n = (w-1)/2;
      int taxicab_dist = abs(x-n)+abs(y-n);
      return (taxicab_dist <= n*1.5);
    } else if (shape.equals("CIR")) {
      float n = (w-1)/2;
      float dist_ = dist(x, y, n, n);
      return (dist_ <= n);
    }
    return false;
  }

  String getShape() {
    String[] parts = s.split(",");
    return parts[0].split("-")[0];
  }

  boolean valid(String s, int x, int y, int w, int h) {
    boolean inShape = shapeValid(getShape(), x, y, w, h);
    if (!inShape) {
      return false;
    }
    String[] parts = s.split(",");
    for (int p = 1; p < parts.length; p++) {
      String[] ruleParts = parts[p].split("-");
      if (ruleParts.length < 4) {
        continue;
      }
      String ruleType = ruleParts[0];
      int ruleEvery = Integer.parseInt(ruleParts[1]);
      int ruleOffset = Integer.parseInt(ruleParts[2]);
      float ruleLength = Float.parseFloat(ruleParts[3]);
      if (y%ruleEvery == ruleOffset) {
        if (ruleType.equals("JGD")) { // jagged
          float frac = 1-((y/4)*0.618033)%1.0; // golden ratio
          if ((float)x/w >= ruleLength*frac) { // past the sus end
            return false;
          }
        } else if (ruleType.equals("HOL")) { // holes (tabs) in the region
          if (x%round(ruleLength) != 0) {
            return false;
          }
        }
      }
    }
    return true;
  }

  int getDiag(int n) {
    int rad = 1;
    boolean found = false;
    while (!found) {
      if (rad*(rad+1)*2+1 >= n) {
        found = true;
        return rad;
      }
      rad++;
    }
    return 1;
  }

  int getSpear(int n) {
    int rad = 1;
    boolean found = false;
    while (!found) {
      if (rad*rad*(rad+1)/2 >= n) {
        found = true;
        return rad;
      }
      rad++;
    }
    return 1;
  }

  boolean inBounds(int x, int y, int w, int h) {
    return (x >= 0 && x < w && y >= 0 && y < h);
  }

  Tile[][] clearMap(String s, int W, int H) {
    Tile[][] result = new Tile[W][H];

    int n = 0;
    for (int y = 0; y < H; y++) {
      for (int x = 0; x < W; x++) {
        if (!valid(s, x, y, W, H)) {
          result[x][y] = null;
        } else {
          result[x][y] = new Tile(this, x, y, n);
          tiles.add(result[x][y]);
          n++;
        }
      }
    }
    return result;
  }

  void drawStrat(float scrX, float scrY, float scrW, float scrH) {
    float midX = scrX+scrW/2;
    float midY = scrY+scrH/2;
    float MARGIN = 2;
    float scale = min(scrW/(tileW+MARGIN), scrH/(tileH+MARGIN));
    float weight = min(1, scale/30);

    pushMatrix();
    translate(midX-tileW/2*scale, midY-tileH/2*scale);
    for (int n = 0; n < tiles.size(); n++) {
      float surge_factor = 0;
      Tile tile = tiles.get(n);
      float x = tile.x;
      float y = tile.y;
      if (tile == cursor_next) {
        fill(0, 255, 0);
      } else if (tile == cursor_curr) {
        fill(255, 0, 0);
      } else {
        float self_prog = (float)tile.steps/strat_max_steps;
        if (abs(prog-self_prog) < 0.2) {
          surge_factor = 0.5+0.5*cos(abs(prog-self_prog)/0.2*PI);
        }
        color c = color(0, 0, 255);
        if (prog >= self_prog) {
          float light = 255-20*(tile.steps-1);
          c = color(light, light, light);
        }
        fill(colorLerp(c, color(255, 255, 255), surge_factor*1.0));
      }
      stroke(surge_factor*0.8*255);
      strokeWeight(2*weight);
      pushMatrix();
      translate(x*scale, y*scale);
      scale(1+surge_factor*0.3);
      rect(-0.5*scale, -0.5*scale, scale, scale);
      popMatrix();
    }
    float pathProg = min(min(prog-1, 1)*(getLongestPath(array, 1)-1), path.size()-1);
    if (prog >= 1.0) {
      float base_thickness = min(max(scale*0.6, 10), 20);
      drawPath(scale, base_thickness*min(max(0, prog-1.0), 0.2));
      drawExplorer(scale, pathProg);
    }
    popMatrix();
    fill(colors[id]);
    textSize(70);
    textAlign(CENTER);
    if (prog >= 1.0) {
      text((int)pathProg, scrX+scrW*0.30, scrY+scrH+100);
      if (pathProg >= path.size()-1 && getLongestPath(array, -1) == path.size()) {
        image(crown, scrX+scrW*0.30-30, scrY+scrH-17, 60, 60);
      }
    }
    textSize(40);
    text("Avg: "+nf(data[0], 0, 2)+", Std dev: "+nf(data[1], 0, 2), scrX+scrW/2, scrY+scrH+155);
    text(names.get(s), scrX+scrW/2, scrY-5);
    drawKeyPad(scrX, scrY, scrW, scrH, pathProg);
  }
  void drawKeyPad(float scrX, float scrY, float scrW, float scrH, float pathProg) {
    float[][] places = {{0, 0.5}, {2, 0.5}, {1, -0.5}, {1, 0.5}};
    float R = 70;
    for (int dire = 0; dire < 4; dire++) {
      pushMatrix();
      translate(scrX+scrW*0.46+R*places[dire][0], scrY+scrH+20+R*places[dire][1]);
      drawKey(0, 0, R*0.8, R*0.8, dire, pathProg);
      popMatrix();
    }
  }
  void drawKey(float x, float y, float w, float h, int dire, float pathProg) {
    float[] rots = {2, 0, 3, 1};
    pushMatrix();
    translate(x+w/2, y+h/2);
    rotate(rots[dire]*PI/2);
    fill(100);

    int piece = max(0, path.size()-2-(int)pathProg);
    float pathProg_piece = pathProg%1.0;
    if (pathProg >= 0 && piece >= 0 && piece < path.size()-1) {
      Tile t1 = path.get(piece);
      if (t1.leadDire == dire) {
        fill(0, 200, 0);
        scale(1.2-0.2*abs(pathProg_piece-0.5)/0.5);
      }
    }
    stroke(0);
    strokeWeight(3);
    rect(-w/2, -h/2, w, h);
    stroke(255);
    line(-w*0.35, 0, w*0.35, 0);
    line(w*0.15, w*0.2, w*0.35, 0);
    line(w*0.15, -w*0.2, w*0.35, 0);
    popMatrix();
  }
  int getLongestPath(Strategy[] array, int sign) {
    int best = 0;
    if (sign == -1) {
      best = -999999999;
    }
    for (int s = 0; s < array.length; s++) {
      if (array[s].path.size()*sign > best) {
        best = array[s].path.size()*sign;
      }
    }
    return best*sign;
  }

  void drawPath(float scale, float thickness) {
    for (int n = 0; n < path.size()-1; n++) {
      Tile thisTile = path.get(n);
      int dire = thisTile.leadDire;
      float x1 = thisTile.x;
      float y1 = thisTile.y;
      float x2 = path.get(n+1).x;
      float y2 = path.get(n+1).y;

      float[] c1 = {x1*scale, y1*scale};
      float[] c2 = {x2*scale, y2*scale};
      if (dire <= 1 && y1 != y2) {
        drawArrow(c1, dire, scale*0.2, thickness, scale);
        drawArrow(dire, c2, scale*0.2, thickness, scale);
      } else {
        drawArrow(c1, c2, scale*0.2, thickness);
      }
    }
  }
  void drawExplorer(float scale, float pathProg) {
    float pathProg_piece = pathProg%1.0;
    int piece = max(0, path.size()-1-(int)pathProg);
    Tile t1 = path.get(piece);
    Tile t2 = path.get(max(0, piece-1));

    float x = lerp(t1.x, t2.x, pathProg_piece);
    float y = lerp(t1.y, t2.y, pathProg_piece);

    if (t2.leadDire == 0 && t1.y > t2.y) {
      if (pathProg_piece >= 0.5) {
        x = t2.x+1-pathProg_piece;
        y = t2.y;
      } else {
        x = t1.x-pathProg_piece;
        y = t1.y;
      }
    }
    if (t2.leadDire == 1 && t1.y < t2.y) {
      if (pathProg_piece >= 0.5) {
        x = t2.x-1+pathProg_piece;
        y = t2.y;
      } else {
        x = t1.x+pathProg_piece;
        y = t1.y;
      }
    }
    pushMatrix();
    translate(x*scale, y*scale);
    fill(0, 100, 255);
    stroke(0);
    strokeWeight(3);
    ellipse(0, 0, scale*0.4, scale*0.4);
    popMatrix();
  }
  color colorLerp(color a, color b, float x) {
    float newR = red(a)+(red(b)-red(a))*x;
    float newG = green(a)+(green(b)-green(a))*x;
    float newB = blue(a)+(blue(b)-blue(a))*x;
    return color(newR, newG, newB);
  }

  void pathfind(int[] path_chosen) {
    path = new ArrayList<Tile>(0);
    cursor_curr = tiles.get(path_chosen[0]);
    cursor_next = tiles.get(path_chosen[1]);
    for (int n = 0; n < tiles.size(); n++) {
      tiles.get(n).steps = 9999999;
    }
    cursor_curr.steps = 0;

    ArrayList<Tile> queue = new ArrayList<Tile>(0);
    queue.add(cursor_curr);
    while (queue.size() >= 1) {
      Tile t = queue.get(0);
      //for (int dire = 0; dire < t.leadTo.length; dire++) {
      for (int dire = t.leadTo.length-1; dire >= 0; dire--) {
        Tile next = t.leadTo[dire];
        if (next != null && next.steps == 9999999) {
          next.leadFrom = t;
          next.leadDire = dire;
          next.steps = t.steps+1;
          queue.add(next);
        }
      }
      queue.remove(0);
    }



    //search(cursor_curr, 0);
    strat_max_steps = 0;
    for (int n = 0; n < tiles.size(); n++) {
      strat_max_steps = max(strat_max_steps, tiles.get(n).steps);
    }
    Tile path_head = cursor_next;
    while (path_head != cursor_curr) {
      path.add(path_head);
      path_head = path_head.leadFrom;
    }
    path.add(cursor_curr);
    buckets[path.size()-1] += 1;
    calculateData();
  }

  void calculateData() {
    int summer = 0;
    int counter = 0;
    for (int b = 0; b < BUCKET_MAX; b++) {
      summer += b*buckets[b];
      counter += buckets[b];
    }
    float mean = (float)summer/counter;
    int stddev = 0;
    for (int b = 0; b < BUCKET_MAX; b++) {
      stddev += pow(b-mean, 2)*buckets[b];
    }
    data[0] = mean;
    data[1] = sqrt((float)stddev/counter);
  }


  /*void search(Tile cursor, int step_level) {
   cursor.steps = step_level;
   for (int dire = 0; dire < cursor.leadTo.length; dire++) {
   Tile next = cursor.leadTo[dire];
   if (next != null && next.steps > step_level) {
   next.leadFrom = cursor;
   next.leadDire = dire;
   search(next, step_level+1);
   }
   }
   }*/

  void drawArrow(int dire, float[] c1, float ARROW_R, float thickness, float scale) {
    float[] c2 = {c1[0]+dires[dire][0]*scale, c1[1]+dires[dire][1]*scale};
    drawArrow(c2, c1, ARROW_R, thickness);
  }

  void drawArrow(float[] c2, int dire, float ARROW_R, float thickness, float scale) {
    int[][] dires = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}};
    float[] c1 = {c2[0]-dires[dire][0]*scale, c2[1]-dires[dire][1]*scale};
    drawArrow(c2, c1, ARROW_R, thickness);
  }

  void drawArrow(float[] c2, float[] c1, float ARROW_R, float thickness) {
    float _dist = d(c1, c2);
    float angle = atan2(c2[1]-c1[1], c2[0]-c1[0]);
    strokeWeight(thickness);
    stroke(255, 0, 0);
    pushMatrix();
    translate(c1[0], c1[1]);
    rotate(angle);

    line(0, 0, _dist, 0);
    line(_dist, 0, _dist-ARROW_R, ARROW_R);
    line(_dist, 0, _dist-ARROW_R, -ARROW_R);
    popMatrix();
  }

  float d(float[] c1, float[] c2) {
    return dist(c1[0], c1[1], c2[0], c2[1]);
  }
}
