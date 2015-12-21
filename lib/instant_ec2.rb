#!/usr/bin/env ruby

# file: instant_ec2.rb

require 'aws-sdk'


class EC2Instance < Hash

  def initialize(h, caller=nil)

    @c = caller
    super().merge!(h)

  end

  def start(duration: nil)

    @c.start_instance self[:instance_id]
    
    if duration then
      
      seconds = duration.to_i * 60
      
      if @c.async then
        Thread.new{ sleep seconds; self.stop} 
      else
        sleep seconds
        self.stop
      end
    end

  end
  
  def stop()

    @c.stop_instance self[:instance_id]

  end  
end

class InstantEC2

  attr_reader :images, :async

  def initialize(credentials: [], region: 'us-east-1', async: true)
    
    @async = async

    @ec2 = Aws::EC2::Client.new(region: region, 
                               credentials: Aws::Credentials.new(*credentials))

    r = @ec2.describe_instances.reservations
    
    ids = @ec2.describe_instances[:reservations].inject({}) do |r, item| 
      x = item.instances[0]
      r.merge(x.image_id => x.instance_id)
    end

    rows = @ec2.describe_images(image_ids: ids.keys)[:images].\
                                                 map{|x| [x.name, x.image_id] }

    @images = rows.inject([]) do |r, x|

      name, image_id = x
      
      r << EC2Instance.new({image_name: name, \
                                         instance_id: ids[image_id]}, self)
      
    end

    @hooks = {
      pending: ->(){ 
        puts "%s: the instance is now pending" % [Time.now]
      },
      running: ->(ip){ 
        puts "%s: the instance is now accessible from %s" % [Time.now, ip]
      },
      stopping: ->(){ puts "%s: the instance is now stopping" % Time.now}
    }

  end

  def find_image(s)
    @images.find {|x| x[:image_name][/#{s}/i]}
  end
  
  def find_pending()

    r = @ec2.describe_instances.reservations.detect do |x|
      x.instances[0].state.name == 'pending'
    end

  end  

  def find_running()

    r = @ec2.describe_instances.reservations.detect do |x|
      x.instances[0].state.name == 'running'
    end

  end
  
  def ip()
    r = self.find_running
    r.instances[0].public_ip_address if r
  end

  def on_pending(&blk)
    @hooks[:pending]= blk
  end  
  
  def on_running(&blk)
    @hooks[:running] = blk
  end    
                                                 
  def on_stopped(&blk)
    @hooks[:stopped] = blk
  end                                                   
  
  def running?
    self.ip ? true : false
  end
  
  # Launch an EC2 instance. Duration (optional) specified in minutes
  #
  def start(s, duration: nil)
    
    self.find_image(s).start duration: duration
    
  end

  def start_instance(id)
    @ec2.start_instances instance_ids: [id]
    @async ? Thread.new { trigger_on_start() } : trigger_on_start()
  end
  
  def stop()

    r = self.find_running()

    if r then
      
      puts 'stopping ...'
      
      self.stop_instance r.instances[0].instance_id      
      
    else
      puts 'no instances to stop'
    end
  end
  
  def stop_instance(id)
    @ec2.stop_instances instance_ids: [id]
    @async ? Thread.new { trigger_on_stopping() } : trigger_on_stopping()
  end

  def stopped?()
    self.ip.nil?
  end
  
  
  private
  
  def trigger_on_start()
    
    # timeout after 60 seconds
    t1 = Time.now
    sleep 10
    sleep 2; pending = self.find_pending() until pending or Time.now > t1 + 60
    
    if pending then
      @hooks[:pending].call()
      trigger_on_running()
    else
      puts 'on_running timedout'
    end
    
  end
                                                 
  def trigger_on_running()
    
    # timeout after 30 seconds
    t1 = Time.now
    sleep 1; ip = self.ip until ip or Time.now > t1 + 30
    
    if ip then 
      @hooks[:running].call(ip)
    else
      puts 'on_running timedout'
    end
    
  end                                                 
  
  def trigger_on_stopping()
    
    # timeout after 30 seconds
    t1 = Time.now
    sleep 7
    sleep 2; ip = self.ip until ip.nil? or Time.now > t1 + 30
    
    if ip.nil? then 
      @hooks[:stopping].call()
    else
      puts 'on_stopping timedout'
    end
    
  end  
end