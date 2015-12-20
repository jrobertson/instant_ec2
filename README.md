# Introducing the instant_ec2 gem

    require 'instant_ec2'

    e = InstantEC2.new credentials: ['youraccesskey', 'yourprivatekey']

    # look for my Windows AMI and then launch the instance

    # query my images (the images which are displayed in
    #  the EC2 Management Console web page)
    #
    e.images
    #=> [{:image_name=>"Windows_Serve...", :instance_id=>"i-327f0f84"}, {:image_...


    e.start 'windows' 

    # Notify me when the Windows EC2 instance is running and
    #   display the public IP address
    #
    e.on_running {|ip| puts 'instance is now accessible from ' + ip}
    #=> instance is now accessible from 54.84.182.27  

    e.stop # stop the instance that is currently running

    # Notify me when the Windows EC2 instance has successfully stopped
    #
    e.on_stopping { puts 'the instance has now stopped'}

## Resources

* instant_ec2 https://rubygems.org/gems/instant_ec2

instant_ec2 gem ec2 aws launch
