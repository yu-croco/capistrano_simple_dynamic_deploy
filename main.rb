# In capistrano definition
require File.expand_path('path/to/this/sourece.rb')
# specify your ELB targtet group name (e.g. 'my-api-server' 'my-web-server'),
# then you can deploy all EC2 instances that are under my-app ELB.
Aws::Ec2.ip_addresses('my-api-server').each.with_index(1) do |ip_addr, idx|
  server "my-api-server-#{idx}",
    user: 'centos',
    roles: %w{rails},
    ssh_options: ssh_options(ipaddr: ip_addr)
end

Aws::Ec2.ip_addresses('my-web-server').each.with_index(1) do |ip_addr, idx|
  server "my-web-server-#{idx}",
    user: 'centos',
    roles: %w{rails},
    ssh_options: ssh_options(ipaddr: ip_addr)
end

# Module
# ELB: see https://docs.aws.amazon.com/sdkforruby/api/Aws/ElasticLoadBalancingV2.html
# EC2: see https://docs.aws.amazon.com/sdkforruby/api/Aws/EC2.html
require 'awk-sdk'
module Aws
  module Ec2
    # elb_target_group_nameにはELBターゲットグループのnameを指定する
    def self.ip_addresses(elb_target_group_name)
      ec2_instances(elb_target_group_name).each_with_object([]) do |i, arr|
        arr << i.instances[0].private_ip_address
      end
    end

    # this will return EC2 ip adresses under specific ELB target group.
    # (e.g.)
    # [app]
    # {"app-01"=>"11.1.1.111", "app-02"=>"11.1.1.555"}
    def self.show_instance_ips
      puts <<-EOS
[app]
#{ip_list}
EOS
    end

    private

    def self.elb_client
      @elb_client ||=
        Aws::ElasticLoadBalancingV2::Client.new(
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        )
    end

    def self.ec2_client
      @ec2_client ||=
        Aws::EC2::Client.new(
          access_key_id: ENV['AWS_ACCESS_KEY_ID'],
          secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
        )
    end

    def self.elb_target_group_arn(elb_target_group_name)
      elb_client
        .describe_target_groups(
          {
            names: [elb_target_group_name]
          }
        )
        .first
        .target_groups[0]
        .target_group_arn
    end

    def self.instance_ids(elb_target_group_name)
      elb_client
        .describe_target_health(target_group_arn: elb_target_group_arn(elb_target_group_name))
        .target_health_descriptions
        .map(&:target)
        .map(&:id)
    end

    def self.ec2_instances(elb_target_group_name)
      ec2_client
        .describe_instances(
          filters:[
            {
              name: 'instance-id',
              values: instance_ids(elb_target_group_name)
            }
          ]
        )
        .reservations
    end

    def self.ip_list
      @ip_list ||= Aws::Ec2::ip_addresses_list('app')
    end
  end
end
