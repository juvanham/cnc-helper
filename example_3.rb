require 'cnc-helper'

# Jurgen Van Ham
# demo for the cnc-helper gem
#
# DC powerstrip
# on connector pair is input, the others are output controlled by a switch


bs=BuildSpace::new(260 , 124  , 21)
# instead of all, enable for each Shape3D
[ :Slot, :Cylinder, :RoundBlock, :Block ].each do |shape3d|
  bs.enable_drill_around(shape3d)
end
bs.set_speed(:zdrill, 60)
bs.zlift=2  # to move above the material 
tool_diameter=4.3 
bottom_z=0.0 # bottom of the material (hardboard)
top_z=18.5   # top of the material (hardboard)

File.open("example3_test.ngc", "w") do |f|
  bs.lead_in(f)
  bs.write(f, {:g=>0, :x=>10, :y=>0,   :z=>top_z+bs.zlift    })
  bs.write(f, {:m=>0                                }) # wait for user
  bs.write(f, {:g=>0,                  :z=>bottom_z })
  bs.write(f, {:m=>0                                }) # wait for user
  bs.write(f, {:g=>0,                  :z=>top_z+bs.zlift    })
  bs.write(f, {:g=>0, :x=>230, :y=>108  })
  bs.write(f, {:g=>1,                  :z=>top_z             })
  bs.write(f, {:m=>0                                }) # wait for user
  components=[]
  count=0
  (0..5).each do |pos|
    count+=1
    components.push ConnectorV::new(bs,      30.0+pos*35, 38.5,  top_z, bottom_z)
    components.push SwitchV::new(bs,         30.0+pos*35, 80.5,  top_z, bottom_z) unless pos==0
    components.push WireDuct::new(bs, 36+pos*35, 64, 6 , 20, top_z,bottom_z) unless pos==0  
  end

  ext_connect=WireDuct::new(bs, 30, 70,  20, 50, top_z, bottom_z)
  
  strip_pos=WireDuct::new(bs, 30+(count*35)/2-15, 90, 35*count-20, 15, top_z, bottom_z)
  
  strip_sw= WireDuct::new(bs, 30+(count*35)/2-15, 65, 35*count-20, 30, top_z, bottom_z)
  
  strip_gnd=WireDuct::new(bs, 30+(count*35)/2-15, 28, 35*count-20, 8, top_z, bottom_z)
  
  drill_holes1=DrillHolesH::new(bs, 30+(count*35)/2, 13,  35*(count-1), top_z, bottom_z)

  drill_holes2=DrillHolesH::new(bs, 30+(count*35)/2, 108,  35*(count-1), top_z, bottom_z)


  bs.mark_outline(f,tool_diameter, top_z, bottom_z) # first mark rectangle 
  components.each do |p|
    p.full(f, tool_diameter)
    bs.comment(f, "wait for user")
    bs.write(f, {:m=>0                                }) 
  end
  ext_connect.full(f,tool_diameter)
  strip_pos.full(f,tool_diameter)
  strip_sw.full(f,tool_diameter)
  strip_gnd.full(f,tool_diameter)
  drill_holes1.full(f,tool_diameter)
  drill_holes2.full(f,tool_diameter)
  
  bs.lead_out(f)
    
end

puts bs.overview

# the SVG file shows what to expect when laying out the parts above
File.open("test3.svg","w") do |f|
  f.puts bs.svg(tool_diameter)
end
