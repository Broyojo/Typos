class Button{
  int id;
  float x;
  float y;
  float w;
  float h;
  String text;
  public Button(int id_, float x_, float y_, float w_, float h_, String text_){
    id = id_;
    x = x_;
    y = y_;
    w = w_;
    h = h_;
    text = text_;
  }
  void drawButton(){
    fill(50,150,250);
    noStroke();
    rect(x,y,w,h);
    fill(255);
    textAlign(CENTER);
    textSize(30);
    text(text,x+w/2,y+h/2+10);
  }
  
  boolean isClicked(float mx, float my){
    return (mx >= x && mx < x+w && my >= y && my < y+h);
  }
  
  void activate(){
    if(id == 6){
      toggleEvolveMode();
      return;
    }
    if(id == 7){
      toggleEvolvePause();
      return;
    }
    cyclesPerFrame = 1;
    if(id == 0){
      FRAMES_PER_RUN = 1000;
    }else if(id == 1){
      FRAMES_PER_RUN = 200;
    }else if(id == 2){
      FRAMES_PER_RUN = 20;
    }else if(id == 3){
      FRAMES_PER_RUN = 3;
    }else if(id == 4){
      FRAMES_PER_RUN = 1;
    }else if(id == 5){
      FRAMES_PER_RUN = 1;
      cyclesPerFrame = 20;
    }
  }
}
