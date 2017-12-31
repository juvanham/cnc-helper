
raise "need to include cnc-helper.rb" unless Tool3D.is_a?(Class)

# meter horizontaal (center X Y)
class MeterH < Tool3D
  def initialize(parent,x1, y1, top_z_, bottom_z_)
    super(parent, top_z_, bottom_z_)
    @w=46
    @h=26
    @x1=x1-@w/2.0
    @y1=y1-@h/2.0
    @x2=@x1+@w
    @y2=@y1+@h
    [ [@x1,@y1], [@x2,@y1], [@x2,@y2], [@x1,@y2]].each do |x,y|
      corner_drill=Drill::new(parent, x, y, top_z_, bottom_z_+2)
      add_part(corner_drill)
    end
    block=Block::new(parent, @x1, @y1, @w, @h, top_z_, bottom_z_)
    add_part(block)
  end

  def outline
    return @x1, @y1, @x2, @y2, parts_bottom_z, parts_top_z
  end
  
  def full(io, tool_diam)
    tool_radius=tool_diam/2.0
    parts_collection.each do |part|
      part.full(io, tool_diam)
    end
    
    [ [@x1+10.5, @x1+21, @y1-1+tool_radius, @y1-2+tool_radius ],
      [@x2-21, @x2-10.5, @y1-1+tool_radius, @y1-2+tool_radius ],
      [@x1+10.5, @x1+21, @y2+1-tool_radius, @y2+2-tool_radius ],
      [@x2-21, @x2-10.5, @y2+1-tool_radius, @y2+2-tool_radius ] ].each do |from_x, to_x, yshallow, ydeep|
      slot_inner  =Slot::new(parent, from_x, ydeep,    to_x, ydeep,    top_z,     bottom_z+4)
      slot_outside=Slot::new(parent, from_x, yshallow, to_x, yshallow, bottom_z+4, bottom_z)
      slot_inner.full(io, tool_diam)
      slot_outside.full(io, tool_diam)
    end
    
    [ [@x1+15.7,   @y1-3+tool_radius ],
      [@x2-15.7,   @y1-3+tool_radius ],
      [@x1+15.7,   @y2+3-tool_radius ],
      [@x2-15.7,   @y2+3-tool_radius ] ].each do | x, y|
      open_notch=Drill::new(parent, x, y, top_z, bottom_z+3)
      open_notch.full(io, tool_diam)
    end  
  end

  def svg(tool_diam)
    return [
      "<rect "+to_svg({:x=>@x1,:y=>@x1, :width=>@w+2, :height=>@h+2, :fill=>'none', :stroke=>'gray', :stroke_width=>200})+" />",
      "<rect "+to_svg({:x=>@x1-3,:y=>@x1-3, :width=>@w+2*3, :height=>@h+2*3, :fill=>'none', :stroke=>'black', :stroke_width=>100})+" />"
    ].join("\n")
  end
  
  
end

# switch vertical led naar onder  (centrum x y)
class SwitchV < Tool3D
  def initialize(parent, x1, y1, top_z_, bottom_z_)
    super(parent, top_z_, bottom_z_)
    @x1=x1
    @y1=y1
    @r=10.5
    cylinder=Cylinder::new(parent, @x1, @y1, @r, top_z_, bottom_z_)
    right_notch=Drill::new(parent, @x1-@r, @y1, top_z_, bottom_z_) # mirror from backside
    
    add_part(cylinder)
    add_part(right_notch)
  end

  def outline
    return @x1-@r+1 ,(@y1-(@r+4)), @x1+@r, (@y1+@r+4), parts_bottom_z, parts_top_z
  end

  def full(io, tool_diam)
    tool_radius=tool_diam/2.0    
    parts_collection.each do |part|
      part.full(io, tool_diam)
    end

    [ [ @x1 , -1 ] ,
      [ @x1 , 1  ] ] .each do |x, sign_y|
      y_inner=@y1+sign_y*(@r-tool_radius+1.5)
      y_outer=@y1+sign_y*(@r-tool_radius+0.5)
      slot_inner=Slot::new(parent, x-2.6, y_inner, x+2.6, y_inner, top_z, bottom_z+3)
      slot_inner.full(io, tool_diam)
      slot_outer=Slot::new(parent, x-2.6, y_outer, x+2.6, y_outer, bottom_z+3, bottom_z)
      slot_outer.full(io, tool_diam)
    end
    
  end

  def svg(tool_diameter)
    return [
      "<circle "+to_svg({:cx=>@x1, :cy=>@y1, :r =>@r, :fill=>'gray', :stroke=>'black', :stroke_width=>200, :fill_opacity=>0.4})+" />", 
      "<circle "+to_svg({:cx=>@x1, :cy=>@y1, :r =>@r+2.6, :fill=>'none', :stroke=>'black', :stroke_width=>100})+" />",
      "<circle "+to_svg({:cx=>@x1-@r, :cy=> @y1, :r=>tool_diameter/2.0,  :fill=>'gray', :stroke=>'gray', :stroke_width=>100, :fill_opacity=>0.4})+" />"
    ].join("\n")
  end

  
end


# dubbele connector Horizontaal center X Y
class ConnectorH < Tool3D

  def initialize(parent, x, y, top_z_, bottom_z_)
    super(parent,top_z_, bottom_z_)
    @w=35
    @h=16.5
    @x=x-@w/2.0
    @y=y-@h/2.0
    rblock= RoundBlock::new(parent,@x,         @y,@w,@h,     top_z_, bottom_z_+3)
    pin_left =Cylinder::new(parent,@x+@h/2,    @y+@h/2.0, 3, top_z_, bottom_z   )
    pin_right=Cylinder::new(parent,@x+@w-@h/2, @y+@h/2.0, 3, top_z_, bottom_z   )
    
    add_part(pin_left)
    add_part(pin_right)
    add_part(rblock)
  end

  def outline
    return @x ,@y, @x+@w, @y+@h, parts_bottom_z, parts_top_z
  end

  def full(io, tool_diam)
    parts_collection.each do |part|
      part.full(io, tool_diam)
    end
  end

  def svg(tool_diam)
     black={:fill=>'black', :stroke=>'black', :stroke_opacity=>0.8, :fill_opacity=>0.2}
     return [
       "<path d=\"M#{1000*(@x+@h/2)},#{1000*@y} a#{1000*@h/2},#{1000*@h/2} 1 1,1 0,#{1000*@w} h#{1000*(@w-@h)} a#{1000*@h/2},#{1000*@h/2} 1 0,1 -#{1000*@h},0 h-#{1000*(@w-@h)}\"  #{to_svg(black)}/>",
       "<circle "+to_svg({:cx=>@x-@h/2.0, :cy=> @y+@h/2.0, :r=>2.5,  :fill=>'gray', :stroke=>'gray', :stroke_width=>50, :fill_opacity=>0.2})+" />",
       "<circle "+to_svg({:cx=>@x+@w-@h/2.0, :cy=> @y+@h/2.0, :r=>2.5,  :fill=>'gray', :stroke=>'gray', :stroke_width=>50, :fill_opacity=>0.2})+" />"
     ].join("\n")
  end
end

# dubbele connector Vertical center X Y
class ConnectorV < Tool3D
  def initialize(parent, x, y, top_z_, bottom_z_)
    super(parent, top_z_, bottom_z_)
    @w=16.5
    @h=35
    @x=x-@w/2.0
    @y=y-@h/2.0
    @rblock= RoundBlock::new(parent, @x,         @y,@w,@h,        top_z_, bottom_z_+3)
    pin_left =Cylinder::new(parent, @x+@w/2.0,  @y+@w/2.0,    3, top_z_, bottom_z)
    pin_right=Cylinder::new(parent, @x+@w/2.0,  @y+@h-@w/2.0, 3, top_z_, bottom_z)
    add_part(pin_left)
    add_part(pin_right)
    add_part(@rblock)
  end

  def outline
    return @x ,@y ,@x+@w, @y+@h, parts_bottom_z, parts_top_z
  end

  def full(io, tool_diam)
    parts_collection.each do |part|
      part.full(io, tool_diam)
    end
  end

  def svg(tool_diam)
    black={:fill=>'black', :stroke=>'black', :stroke_opacity=>0.8, :fill_opacity=>0.2}
    return [
      "<path d=\"M#{1000*@x},#{1000*(@y+@w/2)} a#{1000*@w/2},#{1000*@w/2} 1 1,1 #{1000*@w},0 v#{1000*(@h-@w)} a#{1000*@w/2},#{1000*@w/2} 1 0,1 -#{1000*@w},0 v-#{1000*(@h-@w)}\" #{to_svg(black)}/>",
      "<circle "+to_svg({:cx=>@x+@w/2.0, :cy=> @y+@w/2.0, :r=>2.5,  :fill=>'gray', :stroke=>'gray', :stroke_width=>50, :fill_opacity=>0.2})+" />",
      "<circle "+to_svg({:cx=>@x+@w/2.0, :cy=> @y+@h-@w/2.0, :r=>2.5,  :fill=>'gray', :stroke=>'gray', :stroke_width=>50, :fill_opacity=>0.2})+" />"
    ].join("\n")
  end

  
end



# gleuf voor draden center X Y
class WireDuct < Tool3D
  def initialize(parent, x, y, width, height, top_z_, bottom_z_)
    super(parent, top_z_, bottom_z_)
    @w=width
    @h=height
    @x=x-@w/2.0
    @y=y-@h/2.0
    @block=nil
    if top_z_>bottom_z_+9
      @block= Block::new(parent, @x, @y, @w, @h, top_z_, top_z_-7)
      add_part(@block)
    end
  end

  def outline
    return @x ,@y ,@x+@w, @y+@h, parts_bottom_z , parts_top_z
  end

  def full(io, tool_diam)
    parts_collection.each do |part|
      part.full(io, tool_diam)
    end
  end

  def svg(tool_diam)
    style={:fill=>'black', :stroke=>'black', :fill_opacity=>0.2, :stroke_opacity=>0.3, :stroke_width=>300}
    return "<rect "+to_svg({:x=>@x, :y=>@y, :width =>@w , :height=>@h}.merge(style))+" />"
  end
 
end



# gleuf voor draden center X Y
class DrillHolesH < Tool3D
  def initialize(parent, x, y, width, top_z_, bottom_z_)
    super(parent, top_z_, bottom_z_)
    @w=width
    @x=x-@w/2.0
    @y=y
    distance=20
    steps=(@w/distance).to_i
    offset=(@w-steps*distance)/2.0
    if top_z_>bottom_z_+10
      (0 .. steps).each do |p|
        x=@x+offset+(1.0*p/steps*@w)
        drill= Drill::new(parent, x, @y, top_z_, top_z_-8)
        add_part(drill)
      end
    end
  end

  def outline
    return @x ,@y ,@x+@w, @y, parts_bottom_z, parts_top_z
  end

  def full(io, tool_diam)
    parts_collection.each do |part|
      part.full(io, tool_diam)
    end
  end

  def svg(tool_diam)
    return parts_collection.
             select  { |x| x.respond_to?("svg")   }.
             collect { |part| part.svg(tool_diam) }.
             join("\n")
  end
end



