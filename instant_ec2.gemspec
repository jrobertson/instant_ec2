Gem::Specification.new do |s|
  s.name = 'instant_ec2'
  s.version = '0.1.1'
  s.summary = 'Start your EC2 instance in an instant.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/instant_ec2.rb']
  s.add_runtime_dependency('aws-sdk', '~> 2.2', '>=2.2.7')
  s.signing_key = '../privatekeys/instant_ec2.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'james@r0bertson.co.uk'
  s.homepage = 'https://github.com/jrobertson/instant_ec2'
end
