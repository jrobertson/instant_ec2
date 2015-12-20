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
    Thread.new{ sleep duration * 60; self.stop} if duration

  end
  
  def stop()

    @c.stop_instance self[:instance_id]

  end  
end

class InstantEC2

  attr_reader :images

  def initialize(credentials: [], region: 'us-east-1')

    @ec2 = Aws::EC2::Client.new(region: region, 
                               credentials: Aws::Credentials.new(*credentials))

    r = @ec2.describe_instances.reservations
    image_ids = r.map{|x| x[:instances][0][:image_id] }
    image_names = @ec2.describe_images(image_ids: image_ids).images.\
                                                             map{|x| x.name }
    instance_ids = r.map{|x| x.instances[0].instance_id}

    @images = image_names.zip(instance_ids).inject([]) do |r, x|

      name, id = x
      r << EC2Instance.new({image_name: name, instance_id: id}, self)
      
    end
    
    @hooks = {
      running: ->(ip){ 
        puts "%s: the instance is now accessible from %s" % [Time.now, ip]
      },
      stopping: ->(){ puts "%s: the instance is now stopping" % Time.now}
    }

  end

  def find_image(s)
    @images.find {|x| x[:image_name][/#{s}/i]}
  end

  def find_running()

    r = @ec2.describe_instances.reservations.detect do |x|
      x.instances[0].state.name != 'stopped'
    end

  end
  
  def ip()
    r = self.find_running
    r.instances[0].public_ip_address if r
  end
  
  def on_running(&blk)
    @hooks[:running] = blk
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
    Thread.new { trigger_on_start() }
  end
  
  def stopping

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
    trigger_on_stopping()    
  end

  def stopped?()
    self.ip.nil?
  end
  
  def on_stopped(&blk)
    @hooks[:stopped] = blk
  end  
  
  private
  
  def trigger_on_start()
    
    # timeout after 60 seconds
    t1 = Time.now
    sleep 1; ip = self.ip until ip or Time.now > t1 + 60
    
    if ip then 
      @hooks[:running].call(ip)
    else
      puts 'on_running timedout'
    end
    
  end
  
  def trigger_on_stopping()
    
    # timeout after 30 seconds
    t1 = Time.now
    sleep 1; ip = self.ip until ip.nil? or Time.now > t1 + 30
    
    if ip.nil? then 
      @hooks[:stopping].call()
    else
      puts 'on_stopping timedout'
    end
    
  end  
end