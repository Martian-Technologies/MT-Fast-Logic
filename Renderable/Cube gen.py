# made by catbot
from pathlib import Path
import os


blocks = [
   [1,1,1],
   [2,1,1],
   [2,2,1],
   [2,2,2],
   [3,1,1],
   [4,1,1],
   [4,2,1],
   [4,4,1],
   [8,1,1],
   [8,2,1],
   [8,8,1],
   [8,8,4],
   [12,1,1],
   [12,4,1],
   [16,16,1],
]



for i in range(len(blocks)):
   f1 = open(Path(f"./Renderable/Models/block{str(blocks[i][0])+'x'+str(blocks[i][1])+'x'+str(blocks[i][2])}.obj"), "w")
   f1.write(
      f"""# Blender 4.1.1
# www.blender.org
o Cube
v {0.5*blocks[i][0]}00000 {0.5*blocks[i][1]}00000 {-0.5*blocks[i][2]}00000
v {0.5*blocks[i][0]}00000 {-0.5*blocks[i][1]}00000 {-0.5*blocks[i][2]}00000
v {0.5*blocks[i][0]}00000 {0.5*blocks[i][1]}00000 {0.5*blocks[i][2]}00000
v {0.5*blocks[i][0]}00000 {-0.5*blocks[i][1]}00000 {0.5*blocks[i][2]}00000
v {-0.5*blocks[i][0]}00000 {0.5*blocks[i][1]}00000 {-0.5*blocks[i][2]}00000
v {-0.5*blocks[i][0]}00000 {-0.5*blocks[i][1]}00000 {-0.5*blocks[i][2]}00000
v {-0.5*blocks[i][0]}00000 {0.5*blocks[i][1]}00000 {0.5*blocks[i][2]}00000
v {-0.5*blocks[i][0]}00000 {-0.5*blocks[i][1]}00000 {0.5*blocks[i][2]}00000
vn -0.0000 1.0000 -0.0000
vn -0.0000 -0.0000 1.0000
vn -1.0000 -0.0000 -0.0000
vn -0.0000 -1.0000 -0.0000
vn 1.0000 -0.0000 -0.0000
vn -0.0000 -0.0000 -1.0000
vt 0.625000 0.500000
vt 0.875000 0.500000
vt 0.875000 0.750000
vt 0.625000 0.750000
vt 0.375000 0.750000
vt 0.625000 1.000000
vt 0.375000 1.000000
vt 0.375000 0.000000
vt 0.625000 0.000000
vt 0.625000 0.250000
vt 0.375000 0.250000
vt 0.125000 0.500000
vt 0.375000 0.500000
vt 0.125000 0.750000
s 0
f 1/1/1 5/2/1 7/3/1 3/4/1
f 4/5/2 3/4/2 7/6/2 8/7/2
f 8/8/3 7/9/3 5/10/3 6/11/3
f 6/12/4 2/13/4 4/5/4 8/14/4
f 2/13/5 1/1/5 3/4/5 4/5/5
f 6/11/6 5/10/6 1/1/6 2/13/6
""")
   f2 = open(Path(f"./Renderable/Rends/block{str(blocks[i][0])+'x'+str(blocks[i][1])+'x'+str(blocks[i][2])}.rend"), "w")
   f2.write("""{
   \"lodList\" : [
      {
         \"mesh\" : \"$CONTENT_DATA/Renderable/Models/block""" + str(blocks[i][0])+'x'+str(blocks[i][1])+'x'+str(blocks[i][2]) + """.obj\",
         \"subMeshList\" : [
            {
               \"material\" : \"DifAsgNor\",
               \"textureList\" : [
                  \"$CONTENT_DATA/Renderable/Textures/crab_dif.png\",
                  \"$CONTENT_DATA/Renderable/Textures/default_asg.png\",
                  \"$CONTENT_DATA/Renderable/Textures/default_nor.png\"
               ]
            }
         ]
      }
   ]
}
""")
