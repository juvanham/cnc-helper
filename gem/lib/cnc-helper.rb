
# baseclass
class Shape
  def initialize(parent_)
    @parent=parent_
    raise "#{self.class} argument1 must be a BuildSpace" unless parent_.is_a?(BuildSpace)
  end
  
  def parent
    return @parent
  end

  def lenient_sqrt(v)
    if v<0 and v>-1e-10
      puts "lenient_sqrt(#{v}) assumes 0"
      v=0
    end
    raise Math::DomainError,"#{self.class} sqrt(#{v}) negative #{v}"  if v<0
    return Math.sqrt(v)
  end
  
  # write instruction from a hash to file
  def write(io, h)
    begin
      @parent.write(io, h)
    rescue Exception =>e
      raise "#{self.class} #{e}"
    end
  end

  # write comment to file 
  def comment(io, text)
    @parent.comment(io, text)
  end

  # retrieve the speed based on a key
  def speed(key)
    r=@parent.speed(key)
    raise("unknow speed key #{key}") unless r.is_a?(Numeric)
    return r
  end

  # iterate with defined steps a block (pos,count) (step could be tool diameter)
  def iterate(from, to, step, &block)
    if from==to
      puts "#{self.class}#iterates from #{from} to same #{to}"
      return
    end
    puts "#{self.class}#iterate(#{sprintf("%9.4f, %9.4f",from,to)}, #{step}) " if $DEBUG
    nr_increments=((to-from).abs/step.to_f).ceil
    increment=(to-from)/nr_increments
    pos=from
    counter=0
    puts "#{self.class}#iterate(#{sprintf("%9.4f, %9.4f", from,to)}, steps=#{step}) begin #incr=#{nr_increments}" if $DEBUG
    while counter<=nr_increments
      puts "#{self.class}#iterate(#{sprintf("%9.4f, %9.4f", from,to)}, steps=#{step}) pos=#{sprintf("%9.4f",pos)} counter=#{counter}" if $DEBUG
      block.call(from+increment*counter, counter)
      pos+=increment
      counter+=1
    end
    block.call(to, nr_increments)  # avoid rounding issues
    puts "#{self.class}#iterate(#{sprintf("%9.4f, %9.4f", from,to)}, steps=#{step}) end" if $DEBUG
  end

  # iterate with defined steps a block (pos,count) (step could be tool diameter)
  def iterate_finish(from, to, step, &block)
    if from==to
      puts "#{self.class} iterates from #{from} to same #{to}"
      return
    end
    puts "#{self.class}#iterate_finish(#{sprintf("%9.4f, %9.4f", from, to)}, #{step}) begin " if $DEBUG
    nr_increments=((to-from).abs/step.to_f).ceil
    increment=(to-from)/nr_increments
    iterate(from, to-increment*2/3, step) { |pos, count| block.call(pos, count) }
    puts "#{self.class}#iterate(#{sprintf("%9.4f, %9.4f", from,to)}, steps=#{step}) pos=#{sprintf("%9.4f",to)} counter=#{nr_increments+1} (finishing step)" if $DEBUG
    block.call(to, nr_increments+1)
    puts "#{self.class}#iterate_finish(#{sprintf("%9.4f, %9.4f", from, to)}, #{step}) end" if $DEBUG
  end

  def remove_point_from_array(distance,p,arr)
    raise "expect arg1 to be positive Numeric" unless distance.is_a?(Numeric) and distance>=0
    raise "expect arg2 to be {:x :y} Hash (instead of #{p.class})" unless p.is_a?(Hash)
    raise "expect arg2 to be Array of {:x :y} hashes)" unless p.has_key?(:x) and p.has_key?(:y)
    raise "expect arg3 to be Array" unless arr.is_a?(Array)
    dist2=distance*distance
    n_arr=arr.select do |p1|
      raise "#{self.class} expect arg3 to be array of {:x :y}-hash (not #{p1.class})" unless p1.is_a?(Hash) and p1.has_key?(:x) and p1.has_key?(:y)
      xdiff=p1[:x]-p[:x]
      ydiff=p1[:y]-p[:y]
      (xdiff*xdiff+ydiff*ydiff)>=dist2
    end
    return n_arr
  end

  def move_start_pos(io, tool_diam, h={})
    comment(io, "#{self.class}#startpos")
    p=self.start_pos_t(tool_diam)
    write(io, {:x=>p[:x], :y=>p[:y] }.merge(h))
  end

  def start_pos_t(tool_diam)
    raise "subclass responsibility #{self.class}"
  end
  
end

class Shape2D < Shape
  def initialize(parent_)
    super(parent_)
    @counter=0
  end

  # return the value of the counter without changing
  def counter
    return @counter
  end

  # increment the counter and return its new value
  def count
    @counter+=1
    return @counter
  end

  # go to safe start position
  def start_pos(io, tool_diam, h={})
    raise "subclass responsibility (#{self.class})"
  end

  # drill_around
  def drill_around(tool_diam)
    raise "subclass responsibility (#{self.class})"
  end
  
end


class Rectangle < Shape2D
  def initialize(parent_, x1, y1, w, h)
    super(parent_)
    raise "w must be positive number" unless w.is_a?(Numeric) and w>0
    raise "h must be positive number" unless h.is_a?(Numeric) and h>0
    @x1=x1
    @y1=y1
    @x2=x1+w
    @y2=y1+h
  end

  def get_inside(tool_diam, shrink)
    delta=tool_diam/2.0+shrink
    return @x1+delta, @y1+delta, @x2-delta, @y2-delta
  end

  # alternates fill1 and fill2 
  def fill(io, tool_diam, shrink=0)
    puts "#{self.class}#fill(#{tool_diam})" if $DEBUG
    if count%2==0
      fill1(io, tool_diam, shrink)
    else
      fill2(io, tool_diam, shrink)
    end
  end
  
  def fill1(io, tool_diam, shrink)
    puts "#{self.class}#fill1(#{tool_diam})" if $DEBUG
    from_x, from_y, to_x, to_y=get_inside(tool_diam, shrink)
    comment(io, "Rectangle begin fill1")
    write(io,{:g=>1, :x => from_x, :y=>from_y})
    write(io,{:f=>speed(:fill)} )
    iterate(from_y, to_y, tool_diam) do |pos_y, ycount|
      write(io,{:g=>1, :y=>pos_y})
      if ycount%2==0
        write(io,{:g=>1, :x=>from_x})
      else
        write(io,{:g=>1, :x=>to_x})
      end
    end
    write(io,{:g=>0, :x => (to_x+from_x)/2.0, :y=>(to_y+from_y)/2.0 })
    write(io,{:g=>0, :x => from_x,            :y=>from_y })
    comment(io, "Rectangle end fill1")
  end

  def fill2(io, tool_diam, shrink)
    puts "#{self.class}#fill2(#{tool_diam})" if $DEBUG
    from_x, from_y, to_x, to_y=get_inside(tool_diam, shrink)
    comment(io, "Rectangle begin fill1")
    write(io, {:g=>1, :x => from_x, :y=>from_y})
    write(io,{:f=>speed(:fill)} )
    iterate(from_x, to_x, tool_diam) do |pos_x, xcount|
      write(io, {:g=>1, :x=>pos_x})
      if xcount%2==0
        write(io, {:g=>1, :y=>from_y})
      else
        write(io, {:g=>1, :y=>to_y})
      end
    end
    write(io,{:g=>0, :x => (to_x+from_x)/2.0, :y=>(to_y+from_y)/2.0 })
    write(io,{:g=>0, :x => from_x,            :y=>from_y })
    comment(io, "Rectangle end fill2")
  end

  def draw(io, tool_diam, shrink=0)
    from_x, from_y, to_x, to_y=get_inside(tool_diam, shrink)
    no_x=(to_x-from_x).abs<tool_diam
    no_y=(to_y-from_y).abs<tool_diam
    if no_x or no_y
      puts "skip draw"
      return
    end
    write(io, {:g=>1, :x=>from_x, :y=>from_y})
    write(io, {:g=>1, :y=>to_y})
    write(io, {:g=>1, :x=>to_x})
    write(io, {:g=>1, :y=>from_y})
    write(io, {:g=>1, :x=>from_x})
  end
  
  # go to safe start position
  def start_pos_t(tool_diam)
    return {:x=>@x1+tool_diam/2.0, :y=>@y1+tool_diam/2.0 }
  end

  def drill_around(tool_diam)
    result=[]
    from_x, from_y, to_x, to_y=get_inside(tool_diam, 0)
    steps_w=((to_x-from_x)/(tool_diam*2.0)).to_i
    steps_h=((to_y-from_y)/(tool_diam*2.0)).to_i
    result=[]
    if steps_w>1 and steps_h>1
      (1..steps_w).each do |p|
        puts "#{self.class} drill around w #{p}"
        x=from_x+(to_x-from_x)*(1.0*p/steps_w)
        result.push({:x=>x, :y=>from_y} ) 
        result.push({:x=>x, :y=>to_y  } )   
      end
      (1..steps_h).each do |p|
        puts "#{self.class} drill around h #{p}"
        y=from_y+(to_y-from_y)*(1.0*p/steps_h)
        result.push({:x=>from_x, :y=>y} )
        result.push({:x=>to_x,   :y=>y} )
      end
    end
    result=remove_point_from_array(tool_diam, self.start_pos_t(tool_diam), result)
    result.each do |p|
      result=remove_point_from_array(tool_diam, p, result)
      result.push(p)
    end
    return result
    
  end
  
  def full(io, tool_diam)
    #    write(io,{:f=>speed(:precontour)}  
    #    draw(io, tool_diam, tool_diam)
    fill(io, tool_diam, tool_diam/4)
    write(io,{:f=>speed(:contour)} )              
    draw(io, tool_diam)
    move_start_pos(io, tool_diam, {:g=>0})
  end
  
  private :fill1, :fill2 , :get_inside

end

class Line < Shape2D
  def initialize(parent_, x1, y1, x2, y2)
    super(parent_)
    @x1=x1
    @y1=y1
    @x2=x2
    @y2=y2
    diff_x=(x2-x1)
    diff_y=(y2-y1)
    
    r=2*lenient_sqrt(diff_x*diff_x+diff_y*diff_y)
    @rx=diff_x/r
    @ry=diff_y/r
    
  end

  def p1_x(tool_diam)
    return @x1+@rx*tool_diam
  end

  def p1_y(tool_diam)
    return @y1+@ry*tool_diam
  end

  def p2_x(tool_diam)
    return @x2-@rx*tool_diam
  end

  def p2_y(tool_diam)
    return @y2-@ry*tool_diam
  end

  # alternates fill1 and fill2 
  def fill(io, tool_diam) 
    puts "#{self.class}#fill(#{tool_diam})" if $DEBUG
    comment(io, "Line fill begin #{@x1}, #{@y1} - #{@x2}, #{@y2}  rx=#{@rx} ry=#{@ry}")
    write(io,{:f=>speed(:fill)} ) 
    write(io, { :g=>1, :x=>p2_x(tool_diam), :y=>p2_y(tool_diam) })
    comment(io, "Line fill end  #{@x1}, #{@y1} - #{@x2}, #{@y2}")
  end

  # go to safe start position
  def move_start_pos(io, tool_diam, h={})
    comment(io, "Line startpos")
    write(io, {:x=>p1_x(tool_diam), :y=>p1_y(tool_diam) }.merge(h))
  end
  
  def draw(io, tool_diam, shrink=0)
    #what can we do here?
  end

  def drill_around(tool_diam)
    len_x=p2_x(tool_diam)-p1_x(tool_diam)
    len_y=p2_y(tool_diam)-p1_y(tool_diam)
    steps=lenient_sqrt(len_x*len_x+len_y*len_y)/(2.2*tool_diam)
    result=[]
    if steps>=3
      (1..steps).each do |p|
        x=p1_x(tool_diam)+len_x*p/steps
        y=p1_y(tool_diam)+len_y*p/steps
        result.push({:x=>x, :y=>y} )
      end
    end
    sp_x1=p1_x(tool_diam)
    sp_y1=p1_y(tool_diam)
    sp_x2=p2_x(tool_diam)
    sp_y2=p2_y(tool_diam)

    result=remove_point_from_array(tool_diam/1.5, {:x =>sp_x1, :y=>sp_y1 } , result)
    result=remove_point_from_array(tool_diam/1.5, {:x =>sp_x2, :y=>sp_y2 } , result)
    return result
  end

  def full(io, tool_diam)
    draw(io, tool_diam)
    fill(io, tool_diam) 
    move_start_pos(io, tool_diam, {:g=>0} )
  end
end

class Circle < Shape2D
  def initialize(parent_, ctr_x, ctr_y, r)
    super(parent_)
    raise "#{self.class}:r must be positive number" unless r.is_a?(Numeric) and r>0
    @ctr_x=ctr_x
    @ctr_y=ctr_y
    @r=r
    @x1=ctr_x-r
    @y1=ctr_y-r
    @x2=ctr_x+r
    @y2=ctr_y+r
  end

  def get_inside(tool_diam, shrink)
    delta=tool_diam/2.0+shrink
    return @x1+delta, @y1+delta, @x2-delta, @y2-delta
  end

  def abstract_fill(tool_diam, shrink, &block)
    r1=@r-shrink-tool_diam/2.0
    r2=r1*r1
    iterate(0-r1, r1, tool_diam) do |pos, count|
      co_position=lenient_sqrt(r2-pos*pos)
      block.call(pos+shrink, co_position, count)
    end
  end

  # alternates fill1 and fill2 
  def fill(io, tool_diam, shrink=0)
    puts "#{self.class}#fill(#{tool_diam})" if $DEBUG
    return if @r<=tool_diam
    tool_radius=tool_diam/2.0
    if @r>tool_radius*3
      if count%3==0
        fill1(io, tool_diam, tool_radius, shrink)
      elsif count%3==1
        fill2(io, tool_diam, tool_radius, shrink)
      else
        fill3(io, tool_diam, tool_radius, shrink)
      end
    else
      fill3(io, tool_diam, tool_radius, shrink)
    end
  end
  
  def fill1(io, tool_diam, tool_radius, shrink)
    puts "#{self.class}#fill1(#{tool_diam})" if $DEBUG
    
    from_x, _from_y, _to_x, _to_y=get_inside(tool_diam,shrink)
    comment(io, "Circle fill1-x begin")
    write(io,{:g=>1, :x => from_x, :y=>@ctr_y})
    write(io,{:f=>speed(:fill)} )
    abstract_fill(tool_diam, shrink) do |pos_x, ydiff, count|
      if count%2==0
        write(io, {:g=>1, :x=>@ctr_x+pos_x, :y=>@ctr_y+ydiff-tool_radius})
      else
        write(io, {:g=>1, :x=>@ctr_x+pos_x, :y=>@ctr_y-ydiff+tool_radius})
      end
    end
    write(io,{:g=>1, :x => @ctr_x, :y=>@ctr_y})
    comment(io, "Circle fill1-x end")
  end

  def fill2(io, tool_diam, tool_radius, shrink)
    puts "#{self.class}#fill2(#{tool_diam})" if $DEBUG
    _from_x, from_y, _to_x, _to_y=get_inside(tool_diam, shrink)
    comment(io, "Circle fill2-y begin")
    write(io,{:g=>1, :x => @ctr_x, :y=>from_y})
    write(io,{:f=>speed(:fill)} )             
    abstract_fill(tool_diam, shrink) do |pos_y, xdiff, count|
      if count%2==0
        write(io, {:g=>1, :x=>@ctr_x+xdiff-tool_radius , :y=>@ctr_y+pos_y})
      else
        write(io, {:g=>1, :x=>@ctr_x-xdiff+tool_radius, :y=>@ctr_y+pos_y})
      end
    end
    write(io, {:g=>1, :x => @ctr_x, :y=>@ctr_y})
    comment(io, "Circle fill2-y end")
  end

  def fill3(io, tool_diam, tool_radius, shrink)
    puts "#{self.class}#fill3(#{tool_diam})" if $DEBUG
    comment(io, "Circle fill3-c begin")
    write(io,{:f=>speed(:fill)} )
    iterate(shrink,tool_diam,tool_radius) do |shrink_pos,count|
      _from_x, from_y, _to_x, to_y=get_inside(tool_diam, shrink_pos)
      write(io, {:g=>1, :x=>@ctr_x, :y=>from_y})
      write(io, {:g=>2,             :y=>to_y,   :i=> 0, :j => (to_y-from_y)/2.0})
      write(io, {:g=>2,             :y=>from_y,         :j => (from_y-to_y)/2.0})
    end
    write(io, {:g=>1, :x => @ctr_x, :y=>@ctr_y})
    comment(io, "Circle fill3-c end")
  end

  def draw(io, tool_diam, shrink=0)
    puts "#{self.class}#draw(#{tool_diam})" if $DEBUG
    _from_x, from_y, _to_x, to_y=get_inside(tool_diam, shrink)
    return if @r<tool_diam/2.0
    write(io, {:g=>1, :x=>@ctr_x, :y=>from_y })
    write(io, {:g=>2,             :y=>to_y,   :i=> 0, :j => (to_y-from_y)/2.0 })
    write(io, {:g=>2,             :y=>from_y,         :j => (from_y-to_y)/2.0 })
  end

  def start_pos_t(tool_diam)
    return {:x=>@ctr_x , :y=>@ctr_y-@r+tool_diam/2}
  end

  def drill_around(tool_diam)
    tool_radius=tool_diam/2.0
    r=@r-tool_radius
    circumference=(@r-tool_diam)*2*Math::PI
    steps=(circumference/(1.5*tool_diam)).to_i
    result=[]
    if steps>=3
      (1..steps).each do |p|
        x=@ctr_x+r*Math.cos(2*Math::PI*p/steps)
        y=@ctr_y+r*Math.sin(2*Math::PI*p/steps)
        result.push({:x=>x, :y=>y} )
      end
    end
    result=remove_point_from_array(tool_diam, self.start_pos_t(tool_diam), result)
    return result   
  end
  
  def full(io, tool_diam)
    write(io,{:f=>speed(:precontour)} ) 
    draw(io, tool_diam, tool_diam/5)
    fill(io, tool_diam, tool_diam/3)
    write(io,{:f=>speed(:contour)} ) 
    draw(io, tool_diam)
    move_start_pos(io, tool_diam, {:g=>0})
  end
  private :fill1, :fill2, :get_inside
  
end

class RoundedRect < Shape2D

  def initialize(parent_, x1, y1, w, h)
    super(parent_)
    puts "RoundedRect::new(x1=#{x1}, y1=#{y1} w=#{w} h=#{h})" if $DEBUG
    raise "w must be positive number" unless w.is_a?(Numeric) and w>0
    raise "h must be positive number" unless h.is_a?(Numeric) and h>0
    @x1=x1
    @y1=y1
    @w=w.to_f
    @h=h.to_f
    @x2=@x1+@w
    @y2=@y1+@h
    @is_vertical=(@w<@h)
    double_r=if @is_vertical
               @w
             else
               @h
             end
    @r=double_r/2.0
    @len=if @is_vertical
           @h
         else
           @w
         end
  end

  def get_inside(tool_diam, shrink=0)
    tool_radius=tool_diam/2.0
    delta=tool_radius+shrink
    return @x1+delta, @y1+delta, @x2-delta, @y2-delta
  end

  def get_centers(shrink=0)
    if @is_vertical
      return @y1+@r+shrink, @y2-@r-shrink
    else
      return @x1+@r+shrink, @x2-@r-shrink
    end
  end

  # alternates fill1 and fill2 
  def fill(io, tool_diam, shrink)
    puts "#{self.class}#fill(#{tool_diam})" if $DEBUG
    if count%2==0
      fill1(io, tool_diam, shrink)
    else
      fill2(io, tool_diam, shrink)
    end
  end

  # walk over arc
  def abstract_fill(tool_diam, shrink, &block)
    r1=@r-shrink-tool_diam/2.0
    r2=r1*r1
    iterate(0-r1, r1, tool_diam) do |pos, count|
      co_position=lenient_sqrt(r2-pos*pos)
      block.call(pos+shrink, co_position, count)
    end
  end
  
  def fill1(io, tool_diam, shrink)  
    puts "#{self.class}#fill1(#{tool_diam})" if $DEBUG
    if @is_vertical
      ctr_x=(@x1+@x2)/2
      ctr_y1=@y1+shrink+@r
      ctr_y2=@y2-shrink-@r
      comment(io, "RoundedRect v-fill1-x begin")
      write(io,{:f=>speed(:fill)} )
      write(io, {:g=>1, :x => ctr_x, :y => ctr_y1})
      write(io, {:g=>1, :x => ctr_x, :y => ctr_y2})
      abstract_fill(tool_diam, shrink) do |pos_x, ydiff, count|
        if count%2==0
          write(io, {:g=>1, :x =>ctr_x+pos_x, :y=>ctr_y2+ydiff })
        else
          write(io, {:g=>1, :x =>ctr_x+pos_x, :y=>ctr_y1-ydiff })
        end        
      end
      write(io,{:g=>0, :x=>ctr_x, :y=>ctr_y2})
      comment(io, "RoundedRect end v-fill1-x")
    else
      ctr_y=(@y1+@y2)/2
      ctr_x1=@x1+shrink+@r
      ctr_x2=@x2-shrink-@r
      comment(io, "RoundedRect begin h-fill1-y")
      write(io,{:f=>speed(:fill)} )
      write(io, {:g=>1, :x => ctr_x2, :y=>ctr_y})
      write(io, {:g=>1, :x => ctr_x1, :y=>ctr_y})
      abstract_fill(tool_diam, shrink) do |pos_y, diff_x,count|
        if count%2==0
          write(io, {:g=>1, :x=>ctr_x2+diff_x , :y=>ctr_y+pos_y })
        else
          write(io, {:g=>1, :x=>ctr_x1-diff_x , :y=>ctr_y+pos_y})
        end
      end
      write(io, {:g=>0, :x => ctr_x2, :y=>ctr_y})
      comment(io, "RoundedRect h-fill1-y end")
    end
  end

  def fill2(io, tool_diam, shrink)  # roundedrect
    puts "#{self.class}#fill2(#{tool_diam} shrink=#{shrink})" if $DEBUG
    tool_radius=tool_diam/2.0
    if @is_vertical
      ctr_x=(@x1+@x2)/2
      ctr_y1=@y1+shrink+@r+tool_radius
      ctr_y2=@y2-shrink-@r-tool_radius
      r=@r-(shrink+tool_radius)
      comment(io, "RoundedRect v-fill2-y begin")
      write(io,{:f=>speed(:fill)} )
      write(io, {:g=>1, :x =>ctr_x})
      write(io, {:g=>1, :y =>ctr_y1-r})
      x_at_pos=true
      r2=r*r
      iterate(ctr_y1-r, ctr_y2+r, tool_diam) do |pos_y, count|
        xdiff=0
        if pos_y< ctr_y1
          ydiff=ctr_y1-pos_y
          xdiff=lenient_sqrt(r2-ydiff*ydiff)
        elsif pos_y>ctr_y2
          ydiff=pos_y-ctr_y2         
          xdiff=lenient_sqrt(r2-ydiff*ydiff)
        else
          xdiff=r
        end
        write(io, {:g=>1, :y =>pos_y })
        if x_at_pos
          write(io, {:g=>1, :x =>ctr_x-xdiff})
          x_at_pos=false
        else
          write(io, {:g=>1, :x =>ctr_x+xdiff})
          x_at_pos=true
        end
      end
      write(io, {:g=>1, :x =>ctr_x}) 
      write(io, {:g=>1, :y =>ctr_y1-r})
      comment(io, "RoundedRect v-fill2-y end")
    else
      ctr_y=(@y1+@y2)/2
      ctr_x1=@x1+shrink+@r+tool_radius
      ctr_x2=@x2-shrink-@r-tool_radius
      r=@r-(shrink+tool_radius)
      comment(io, "RoundedRect v-fill2-x begin")
      write(io,{:f=>speed(:fill)} )              
      write(io, {:g=>1, :y =>ctr_y})
      write(io, {:g=>1, :x =>ctr_x1-r})
      y_at_pos=true
      r2=r*r
      iterate(ctr_x1-r, ctr_x2+r, tool_diam) do |pos_x, count|
        ydiff=0
        if   pos_x<ctr_x1
          xdiff=ctr_x1-pos_x
          ydiff=lenient_sqrt(r2-xdiff*xdiff)
        elsif pos_x>ctr_x2
          xdiff=pos_x-ctr_x2
          ydiff=lenient_sqrt(r2-xdiff*xdiff)
        else
          ydiff=r
        end
        write(io, {:g=>1, :x =>pos_x})
        if y_at_pos
          write(io, {:g=>1, :y =>ctr_y-ydiff})
          y_at_pos=false
        else
          write(io, {:g=>1, :y =>ctr_y+ydiff})
          y_at_pos=true
        end
      end
      write(io, {:g=>1, :y =>ctr_y})
      write(io, {:g=>1, :x =>ctr_x1-r})
      comment(io, "RoundedRect v-fill2-x end")

    end
  end
  
  def draw(io, tool_diam, shrink=0)
    puts "#{self.class}#draw(#{tool_diam})" if $DEBUG
    from_x, from_y, to_x, to_y=get_inside(tool_diam, shrink)
    no_x=(to_x-from_x).abs<tool_diam
    no_y=(to_y-from_y).abs<tool_diam
    if no_x or no_y
      puts "#{self.class}#draw(#{tool_diam}) skip draw"
      return
    end
    tool_radius=tool_diam/2.0
    r=@r-(shrink+tool_radius)
    if r>tool_radius
      if @is_vertical
        ctr_x=(@x1+@x2)/2              
        write(io, {:g=>1, :x=>ctr_x-r, :y=>@y1+r })
        write(io, {:g=>3, :x=>ctr_x+r,            :i=>r , :j=>0})
        write(io, {:g=>1,              :y=>@y2-r })
        write(io, {:g=>3, :x=>ctr_x-r,            :i=>-r })
        write(io, {:g=>1,              :y=>@y1+r })
      else
        ctr_y=(@y1+@y2)/2
        write(io, {:g=>1, :x=>@x1+r,   :y=>ctr_y-r})
        write(io, {:g=>2,                        :y=>ctr_y+r,   :i=>0, :j=>r })
        write(io, {:g=>1, :x=>@x2-r })
        write(io, {:g=>2,                        :y=>ctr_y-r,          :j=>-r })
        write(io, {:g=>1, :x=>@x1+r })
      end
    end
  end

  def start_pos_t(tool_diam)
    from_x, from_y, _to_x, _to_y=get_inside(tool_diam, 0)
    tool_radius=tool_diam/2.0
    if @is_vertical
      return {:x=>from_x,    :y=>from_y+@r-tool_radius}
    else
      return {:x=>from_x+@r-tool_radius, :y=>from_y}
    end
  end

  def drill_around(tool_diam)
    tool_radius=tool_diam/2.0
    result=[]
    steps_arc=(@r*Math::PI)/(1.6*tool_diam)
    distance=0
    if @is_vertical
      distance=@h-2*@r-tool_diam
    else
      distance=@w-2*@r-tool_diam
    end
    steps_line=(distance/(1.8*tool_diam)).to_i
    return result if (steps_line+steps_arc) < 3
    if @is_vertical
      (1 .. steps_line).each do |p|
        result.push({:x=>@x1+tool_radius, :y=>@y1+tool_radius+(1.0*p/steps_line)*distance })
        result.push({:x=>@x2-tool_radius, :y=>@y1+tool_radius+(1.0*p/steps_line)*distance })
      end
    else
      (1 .. steps_line).each do |p|
        result.push({:x=>@x1+tool_radius+(1.0*p/steps_line)*distance, :y=>@y1+tool_radius })
        result.push({:x=>@x1+tool_radius+(1.0*p/steps_line)*distance, :y=>@y2-tool_radius })
      end
    end
    if @is_vertical
      abstract_fill(tool_diam*1.6, 0) do |posx, ydiff, count|
        result.push({:x=> @x1+@r+posx, :y=>@y1+@r-ydiff })
        result.push({:x=> @x1+@r+posx, :y=>@y2-@r+ydiff })       
      end    
    else
      abstract_fill(tool_diam*1.6, 0) do |posy, xdiff, count|
        result.push({:x=> @x1+@r-xdiff, :y=>@y1+@r-posy })
        result.push({:x=> @x2-@r+xdiff, :y=>@y1+@r-posy })       
      end    
    end
    nresult=result
    result.each do |p|
      nresult=remove_point_from_array(tool_diam, p, nresult)
      nresult.push p                       
    end
    nresult=remove_point_from_array(tool_diam, self.start_pos_t(tool_diam), nresult)
    return nresult
  end
  
  def full(io, tool_diam)
    write(io,{:f=>speed(:precontour)} )  
    draw(io, tool_diam, tool_diam/4)
    fill(io, tool_diam, tool_diam/3)
    write(io,{:f=>speed(:contour)} ) 
    draw(io, tool_diam)
    move_start_pos(io, tool_diam, {:g=>0})
  end
  
  private :fill1, :fill2, :get_inside, :abstract_fill, :get_centers
end

class Shape3D < Shape
  def initialize(parent_, top_z_, bottom_z_)
    super(parent_)
    raise "#{self.class} top_z must be defined" if top_z_.nil?
    raise "#{self.class} bottom_z must be defined" if bottom_z_.nil?
    @top_z=top_z_
    @bottom_z=bottom_z_
  end
  
  def top_z
    return @top_z
  end
  
  def bottom_z
    return @bottom_z
  end

  # decide in which direction to move from top_z to bottom_z
  def step
    step=1.0
    step*=-1 if @bottom_z<@top_z
  end

  # utility to cut a 2D object top top_z to bottom_z with defined steps
  def full_abstract(io, tool_diam, z_step, obj)
    raise "#{self.class}#full_abstract needs a Shape2D" unless obj.is_a?(Shape2D)
    write(io, {:g =>0, :z=>zlift(top_z)})
    obj.move_start_pos(io, tool_diam, {:g=>0})
    write(io,{:f=>speed(:zdrill)} )
    iterate(top_z, bottom_z, z_step*5) do |pos_z, counter| 
      write(io, {:g =>1, :z=>pos_z})
      write(io, {:g =>0, :z=>zlift(top_z)})
      write(io, {:g =>0, :z=>zlift(pos_z)}) if zlift(pos_z)<top_z
    end 
    write(io, {:g =>0, :z=>zlift(top_z)})
    iterate_finish(top_z, bottom_z+z_step/2.0, z_step) do |pos_z, counter|
      write(io,{:f=>speed(:zdrill)} )            
      write(io,{ :g=>1, :z=>pos_z})
      obj.full(io, tool_diam)
    end    
    write(io,{ :g=>1, :z=>bottom_z})
    obj.full(io, tool_diam)
  end

  def enabled_drill_around?
    puts "enabled_drill_around? (#{self.class})" if $DEBUG
    return @parent.enabled_drill_around?(self.class.name)
  end
  
  def collect_drill_around_points(tool_diam, obj, top_z, bottom_z)
    raise "expected arg1 as a Numeric" unless tool_diam.is_a?(Numeric)
    raise "expected arg2 as a Shape2D (not #{obj.class})" unless obj.is_a?(Shape2D)
    raise "expected arg3 as a Numeric" unless top_z.is_a?(Numeric)
    raise "expected arg3 as a Numeric" unless bottom_z.is_a?(Numeric)
    points_around=obj.drill_around(tool_diam)
    pts=points_around.collect do |p|
      raise "#{self.class} expect :x key in #{p.class}" unless p.is_a?(Hash) and p.has_key?(:x)
      raise "#{self.class} expect :y key in #{p.class}" unless p.is_a?(Hash) and p.has_key?(:y)
      puts "#{self.class} drill_around #{sprintf("x=%9.4f  y=%9.4f",p[:x],p[:y])}" if $DEBUG
      Drill::new(@parent, p[:x], p[:y], top_z, bottom_z)
    end
    return pts
  end

  def drill_around_points(io, tool_diam, point_array, home_x, home_y)    
    raise "expected arg1 as a Numeric" unless tool_diam.is_a?(Numeric)
    raise "expected arg2 as an array" unless point_array.is_a?(Array)
    raise "expected arg3 as a Numeric" unless home_x.is_a?(Numeric)
    raise "expected arg4 as a Numeric" unless home_y.is_a?(Numeric)
    return unless enabled_drill_around?
    if point_array.empty?
      comment(io, "no walk around for  #{self.class}")
      return
    end
    comment(io, "walk around for #{self.class} in #{point_array.size} drill holes, begin" )
    point_array.collect do |drill_pnt|
      raise "array elem expected Drill" unless drill_pnt.is_a?(Drill)
      write(io, {:g =>0, :z=>zlift(top_z)} )
      write(io, {:g =>0, :x => home_x, :y => home_y} )
      drill_pnt.full(io,tool_diam)
    end
    comment(io, "walk around for #{self.class} in #{point_array.size} drill holes, end" )
  end
  
  
  # utility to add zlift from BuildSpace on top of (top_z) to move safely
  def zlift(z)
    local_lift=z+@parent.zlift
    _x1, _x2, _y1, _y2, bot_z, top_z=@parent.outline
    global_lift=((top_z.nil?)?0:top_z)+@parent.zlift
    return [local_lift,global_lift].max
  end

  def to_svg(h)
    raise "#{self.class}#to_svg expects hash " unless h.is_a?(Hash)
    [ :x, :y, :cx, :cy, :height, :width, :r ].each do |key|
      h[key]=(h[key]*1000.0).to_i if h.has_key?(key)
    end
    return h.keys.collect do |k|
      s=k.to_s.gsub(/_/,"-")
      "#{s}=\"#{h[k]}\""
    end .join(" ")
  end
  
  
end

class Slot < Shape3D
  def initialize(parent_, x1, y1, x2, y2, top_z_, bottom_z_)
    super(parent_, top_z_, bottom_z_)
    @line=Line::new(parent, x1, y1, x2, y2)
  end

  def full(io, tool_diam, zstep=1)
    line_points=collect_drill_around_points(tool_diam, @line, top_z, bottom_z )
    write(io, {:g =>0, :z=>zlift(top_z)})
    write(io, {:g =>0, :x=>@line.p2_x(tool_diam), :y=>@line.p2_y(tool_diam)})
    write(io,{:f=>speed(:zdrill)} )
    iterate_finish(top_z, bottom_z, zstep*5) do |pos_z, counter| 
      write(io, {:g =>0, :z=>zlift(pos_z) }) if zlift(pos_z)<zlift(top_z)
      write(io, {:g =>1, :z=>pos_z})
      write(io, {:g =>0, :z=>zlift(top_z) })
    end
    write(io, {:g =>0, :x=>@line.p1_x(tool_diam), :y=>@line.p1_y(tool_diam)})
    write(io,{:f=>speed(:zdrill)} )
    iterate_finish(top_z, bottom_z, zstep*5) do |pos_z, counter|
      write(io, {:g =>0, :z=>zlift(pos_z) }) if zlift(pos_z)<zlift(top_z)
      write(io, {:g =>1, :z=>pos_z})
      write(io, {:g =>0, :z=>zlift(top_z)})
    end
    line_points=remove_point_from_array(tool_diam,
                                        {:x=>@line.p1_x(0), :y=> @line.p1_y(0) },
                                        line_points,
                                       )
    line_points=remove_point_from_array(tool_diam,                                       
                                        {:x=>@line.p2_x(0), :y=>@line.p2_y(0) },
                                        line_points
                                       )
    drill_around_points(io, tool_diam, line_points, @line.p1_x(tool_diam), @line.p1_y(tool_diam) )
    iterate(top_z, bottom_z, zstep) do |pos_z, counter|
      write(io,{:f=>speed(:zdrill)} ) 
      write(io,{ :g=>1, :z=>pos_z})
      @line.full(io, tool_diam)
    end
  end

end

# a hole with tooldiameter since there is no movement except for Z
class Drill < Shape3D
  def initialize(parent_, x, y, top_z_, bottom_z_)
    super(parent_, top_z_, bottom_z_)
    @x=x
    @y=y
  end

  def full(io, tool_diam, zstep=1)
    write(io,{:g =>0, :z=>zlift(top_z)})
    write(io,{:g =>0, :x=>@x , :y=>@y})
    iterate_finish(top_z, bottom_z, zstep*5) do |pos_z, counter|
      write(io, {:f=>speed(:zdrill)} )
      write(io, {:g =>0, :z=>zlift(pos_z)})  if zlift(pos_z)<top_z
      write(io, {:g =>1, :z=>pos_z})
      write(io, {:g =>0, :z=>zlift(top_z)})
    end
    write(io, {:g =>0, :z=>zlift(top_z)})
  end

  def svg(tool_diam)
    return  "<circle "+to_svg({:cx=>@x, :cy=>@y, :r =>tool_diam/2.0, :stroke=>'red', :stroke_width=>300, :stroke_opacity=>0.9})+" />"
  end

end

# a hole with specified diameter
class Cylinder < Shape3D
  def initialize(parent_, ctr_x, ctr_y, radius, top_z_, bottom_z_)
    super(parent_, top_z_, bottom_z_)
    @ctr_x=ctr_x
    @ctr_y=ctr_y
    @radius=radius
    @disc=Circle::new(parent, ctr_x, ctr_y, radius)
  end
  
  def full(io, tool_diam, zstep=1)
    circle_points=collect_drill_around_points(tool_diam,
                                              @disc,
                                              top_z, bottom_z)
    center_drill=Drill::new(parent, @ctr_x, @ctr_y, top_z, bottom_z)
    comment(io, "Cylinder center drill begin")
    write(io, {:g =>0, :z=>zlift(top_z)})
    center_drill.full(io,tool_diam)
    write(io,{:g =>0, :z=>zlift(top_z)})
    comment(io, "Cylinder center drill end")
    drill_around_points(io, tool_diam, circle_points, @ctr_x, @ctr_y-@radius-tool_diam/2.0)
    write(io,{:g =>0, :z=>zlift(top_z)})
    full_abstract(io, tool_diam, zstep, @disc)
  end
  
end

# internal
class Block < Shape3D
  def initialize(parent_, x1, y1, w, h, top_z_, bottom_z_)
    super(parent_, top_z_, bottom_z_)
    @x1=x1
    @y1=y1
    @w=w
    @h=h
    @rect=Rectangle::new(parent, x1, y1, w, h)
  end
  
  def full(io, tool_diam, zstep=1)
    rectangle_points=collect_drill_around_points(tool_diam, @rect, top_z, bottom_z)
    drill_around_points(io, tool_diam, rectangle_points, @x1, @y1) 
    full_abstract(io, tool_diam, zstep, @rect)
  end
  
end

# internal
class RoundBlock < Shape3D
  def initialize(parent_, x1, y1, w, h, top_z_, bottom_z_)
    super(parent_, top_z_, bottom_z_)
    @x1=x1
    @y1=y1
    @rnrect=RoundedRect::new(parent, x1, y1, w, h)
  end

  def full(io, tool_diam, zstep=1)
    rnrect_points=collect_drill_around_points(tool_diam, @rnrect, top_z, bottom_z)
    drill_around_points(io, tool_diam, rnrect_points, @x1, @y1)
    full_abstract(io, tool_diam, zstep, @rnrect)
  end
end

# internal class to derive high level components
class Tool3D < Shape3D
  def initialize(parent, top_z, bottom_z)
    super(parent, top_z, bottom_z)
    parent.add_tool(self)
    @parts=[]
  end

  # tools are composed by registering parts
  def add_part(part)
    raise "#{self.class} needs parts than handle full" unless part.respond_to?('full')
    @parts.push(part)
  end

  # the collections of registered parts
  def parts_collection
    return @parts
  end

  # returns the highest top of the parts, optionally a value or a collection can be considered 
  def parts_top_z(default=nil)
    tops=parts_collection.collect { |part| part.top_z}
    tops.concat([default]) unless default.nil?
    top_result=tops.flatten.compact.max
    unless top_result.nil?
      raise "#{self.class} parts_top_z above top_z" unless top_result>=top_z
    end
    return top_result
  end

  # returns the lowest bottom of the parts, optionally a value or a collection can be considered 
  def parts_bottom_z(default=nil)
    bottoms=parts_collection.collect { |part| part.bottom_z}
    bottoms.concat([default]) unless default.nil?
    bottom_result=bottoms.flatten.compact.min
    unless bottom_result.nil?
      raise "#{self.class} parts_bottom_z below bottom_z" unless bottom_result>=bottom_z
    end
    return bottom_result
  end
  
  def outline
    raise "subclass responsibility"
  end

  def svg(tool_diam)
    raise "Subclass responsability"
  end

  
end


class BuildSpace
  def initialize(dim_x_, dim_y_, dim_z_)
    @dim_x=dim_x_
    @dim_y=dim_y_
    @dim_z=dim_z_
    @z_lift=2
    @toollist=[]
    @speedtable={}
    @drill_around_enabled={}
    multi_set_speed(200)
  end

  def multi_set_speed(speed)
    set_speed(:zdrill,     speed*0.4)
    set_speed(:precontour, speed*0.8)
    set_speed(:contour,    speed*0.5)
    set_speed(:fill,       speed)
  end
  
  def add_tool(t)
    raise "only Tool3D subclasses" unless t.is_a?(Tool3D)
    @toollist.push(t)
  end

  def used_by_tools
    @toollist.collect do |tool|
      x1, y1, x2, y2=tool.outline      
      [ "#{sprintf("%15s", tool.class.to_s)} ",
        " (X=#{sprintf("%8.4f", x1)}, Y=#{sprintf("%8.4f",y1)}) -",
        " (X=#{sprintf("%8.4f", x2)}, Y=#{sprintf("%8.4f",y2)})"
      ].join('')
    end
  end

  def outline
    min_x=nil
    max_x=nil
    min_y=nil
    max_y=nil
    min_z=nil
    max_z=nil
    @toollist.each do |tool|
      x1, y1, x2, y2, z1, z2=tool.outline
      min_x=x1 if min_x.nil? or x1<min_x
      max_x=x2 if max_x.nil? or x2>max_x
      min_y=y1 if min_y.nil? or y1<min_y
      max_y=y2 if max_y.nil? or y2>max_y
      min_z=z1 if not min_z.nil? and (min_z.nil? or z1<min_z)
      max_z=z2 if not max_z.nil? and (max_z.nil? or z2>max_z)
    end
    return min_x, min_y, max_x, max_y, min_z, max_z
  end


  def mark_outline(io, tool_diam, top_z, bottom_z=0)
    comment(io, "mark the outline, begin")
    xleft, ytop, xright, ybottom, _zbottom, ztop=outline
    ztop=[ztop,top_z].compact.max
    tool_radius=tool_diam/2.0
    write(io, {:g=>0, :z=>ztop+zlift})

    write(io, {:g=>0, :x=>xleft+tool_radius, :y=>ytop+tool_radius} )
    write(io,{:f=>speed(:zdrill)} ) 
    write(io, {:g=>1, :z=>top_z})
    write(io, {:g=>0, :z=>ztop+zlift})

    write(io, {:g=>0, :x=>xright-tool_radius                     } )
    write(io,{:f=>speed(:zdrill)} )
    write(io, {:g=>1, :z=>top_z})
    write(io, {:g=>0, :z=>ztop+zlift})

    write(io, {:g=>0,                         :y=>ybottom-tool_radius} )
    write(io,{:f=>speed(:zdrill)} )         
    write(io, {:g=>1, :z=>top_z})
    write(io, {:g=>0, :z=>ztop+zlift})

    write(io, {:g=>0, :x=>xleft+tool_radius } )
    write(io,{:f=>speed(:zdrill)} ) 
    write(io, {:g=>1, :z=>top_z})
    write(io, {:g=>0, :z=>ztop+zlift})

    write(io, {:g=>0,                         :y=>ytop+tool_radius} )
    write(io,{:f=>speed(:zdrill)} ) 
    write(io, {:g=>1, :z=>top_z})
    write(io, {:g=>0, :z=>ztop+zlift})
    comment(io, "mark the outline, end")
    comment(io, "when all positions were correct, press resume")
    write(io, {:m=>0})
  end

  def dim_x
    return @dim_x
  end
  
  def dim_y
    return @dim_y
  end
  
  def dim_z
    return @dim_z
  end

  def zlift
    return @z_lift
  end

  def speed(key)
    return @speedtable[key]
  end

  def set_speed(key,val)
    raise "speed key expects a symbol" unless key.is_a?(Symbol)
    raise "speed value expects a numeric" unless val.is_a?(Numeric)
    puts "set_speed(#{key}, #{val.to_i})"if $DEBUG
    @speedtable[key]=val.to_i
  end

  def enabled_drill_around?(key)
    key=key.to_sym if key.is_a?(String)
    if @drill_around_enabled.has_key?(:all)
      puts "enabled_drill_around(#{key}) == true (because :all)" if $DEBUG
      return true
    end
    if @drill_around_enabled.has_key?(key)
      result=@drill_around_enabled.has_key?(key)
      puts "enabled_drill_around(#{key}) == #{result} (explicit)" if $DEBUG
      return result
    end
    puts "enabled_drill_around(#{key}) == false (because fallback)" if $DEBUG
    return false
  end

  def enable_drill_around(key)
    raise "enable_drill_around expects symbol" unless key.is_a?(Symbol)
    @drill_around_enabled[key]=true  
    @drill_around_enabled.keys.each { |k| @drill_around_enabled[k]=true } if key==:all
  end
  
  def disable_drill_around(key)
    @drill_around_enabled[key]=false if @drill_around_enabled.has_key?(key)
    @drill_around_enabled={} if key==:all
  end
  
  def zlift=(v)
    raise "#{self.class} zlift= expects positive numeric" unless v.is_a?(Numeric) and v>0
    @z_lift=v
  end
  
  
  def write(io, h)
    raise "write arg1 needs to be IO" unless io.is_a?(IO)
    raise "write arg2 needs to be Hash" unless h.is_a?(Hash)
    supported_keys=[ :m, :g, :f, :x, :y, :z, :i, :j]
    h.keys.each do |k|
      raise "writing key #{k} not supported" unless supported_keys.include?(k)
    end
    fmt="%09.4f" # for floating point numbers
    str=''
    str+="m#{h[:m]} " if h.has_key?(:m)
    str+="g#{h[:g]} " if h.has_key?(:g)
    str+="f#{h[:f]} " if h.has_key?(:f)
    str+="x#{sprintf(fmt,h[:x])} " if h.has_key?(:x)
    str+="y#{sprintf(fmt,h[:y])} " if h.has_key?(:y)
    str+="z#{sprintf(fmt,h[:z])} " if h.has_key?(:z)
    str+="i#{sprintf(fmt,h[:i])} " if h.has_key?(:i)
    str+="j#{sprintf(fmt,h[:j])} " if h.has_key?(:j)
    raise "X(#{h[:x]}) out of bound #{@dim_x}" if h.has_key?(:x) and h[:x]>dim_x
    raise "Y(#{h[:y]}) out of bound #{@dim_y}" if h.has_key?(:y) and h[:y]>dim_y
    raise "Z(#{h[:z]}) out of bound #{@dim_z}" if h.has_key?(:z) and h[:z]>dim_z
    raise "X(#{h[:x]}) out of bound 0" if h.has_key?(:x) and h[:x]<0
    raise "Y(#{h[:y]}) out of bound 0" if h.has_key?(:y) and h[:y]<0
    raise "Z(#{h[:z]}) out of bound 0" if h.has_key?(:z) and h[:z]<0
    io.puts(str)
  end

  def comment(io, text)
    raise "write arg1 needs to be IO" unless io.is_a?(IO)
    raise "write arg2 needs to be String" unless text.is_a?(String)
    io.puts("(#{text})")
  end

  # setup to run the program
  def lead_in(io)
    comment(io, "g40 no tool compensation")
    write(io, {:g =>40})
    comment(io, "g90 absolute position")
    write(io, {:g =>90})
    comment(io, "g21 use mm")
    write(io, {:g =>21})
    comment(io, "speed #{speed(:zdrill)} mm/min")
    write(io, {:f =>speed(:zdrill)})
    comment(io, "lift tool to the top")
    write(io, {:g=>1, :z=> dim_z})
  end

  # write the end of the program
  def lead_out(io)
    comment(io, "lift tool to the top")
    write(io, {:g=>1, :z=> dim_z})
    comment(io, "m2 indicates end of program")
    write(io, {:m =>2})
  end

  def overview
    str =" ================\n"
    str+=" = l a y o u t  =\n"
    str+=" ================\n"
    str+=self.used_by_tools.join("\n")
    str+="\n\n"
    str+=" =================\n"
    str+=" = Bounding box  =\n"
    str+=" =================\n"
    x1, y1, x2, y2, z1, z2=self.outline
    str+="(X=#{sprintf("%8.4f",x1)}, Y=#{sprintf("%8.4f",y1)})\n"
    str+="      --\n"
    str+="           (X=#{sprintf("%8.4f",x2)}, Y=#{sprintf("%8.4f",y2)})\n"
    str+="#{sprintf("%8.4f",z1)} < Z < #{sprintf("%8.4f",z2)}\n"
    return str
  end

  def svg(tool_diam)
    min_x, min_y, max_x, max_y, min_z, max_z=outline
    header=[]
    header.push "<?xml version=\"1.0\" standalone=\"no\"?>"
    header.push "<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\" \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">"
    header.push "<svg width=\"12cm\" height=\"4cm\" viewBox=\"#{min_x} #{min_y} #{max_x*1000} #{max_y*1000}\""
    header.push "xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\">"
    body=@toollist.select { |p| p.respond_to?("svg") }.collect { |p| p.svg(tool_diam)} . join("\n")
    footer=["</svg>"]
    [header,body,footer].flatten.join("\n")
  end

end

require 'components'
