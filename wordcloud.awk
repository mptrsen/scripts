#!/bin/awk -f

BEGIN { 
    WIDTH=1000
    HEIGHT=600
    SCALE=1
    
    OFS=""
    
    print "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>"
    print "<svg width=\"",WIDTH,"\" height=\"", HEIGHT,"\" version=\"1.1\" xmlns=\"http://www.w3.org/2000/svg\">"
}

{ 
R = int(rand()*9)
G = int(rand()*9)
B = int(rand()*9)

print "<text style=\"fill:#",R,G,B,";opacity:1; font-size:",$1*SCALE,"px;\" x=\"",rand()*(WIDTH-100),"\" y=\"",rand()*HEIGHT,"\">",$2,"</text>" 
}

END { print "</svg>" }
