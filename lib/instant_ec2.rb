#!/usr/bin/env ruby

# file: instant_ec2.rb

require 'aws-sdk'


class EC2Instance < Hash

  def initialize(h, ec2=nil)

    @ec2 = ec2
    super().merge!(h)

  end

  def start()

    @ec2.start_instances instance_ids: [self[:instance_id]]

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
      r << EC2Instance.new({image_name: name, instance_id: id}, @ec2)
      
    end

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
  
  def on_running()
    
    # timeout after 30 seconds
    t1 = Time.now
    sleep 1; ip = self.ip until ip or Time.now > t1 + 30
    
    if ip then 
      yield(ip) 
    else
      puts 'on_running timedout'
    end
    
  end
  
  alias running find_running

  def start(s)
    self.find_image(s).start
  end

  def stop

    r = self.find_running()

    if r then
      
      puts 'stopping ...'
      instance_id = r.instances[0].instance_id      
      @ec2.stop_instances instance_ids: [instance_id]
      
    else
      puts 'no instances to stop'
    end
  end
  
  def on_stopping()
    
    # timeout after 30 seconds
    t1 = Time.now
    sleep 1; ip = self.ip until ip.nil? or Time.now > t1 + 30
    
    if ip.nil? then 
      yield
    else
      puts 'on_stopping timedout'
    end
    
  end  
end
