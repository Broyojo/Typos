class Tile{
  int x;
  int y;
  int n;
  Tile[] leadTo;
  int steps = -1;
  Tile leadFrom = null;
  int leadDire = 0;
  public Tile(Strategy strat, int x_, int y_, int n_){
    x = x_;
    y = y_;
    n = n_;
    strat.tileW = max(strat.tileW,x+1);
    strat.tileH = max(strat.tileH,y+1);
    leadTo = new Tile[4];
    for(int t = 0; t < 4; t++){
      leadTo[t] = null;
    }
  }
}
