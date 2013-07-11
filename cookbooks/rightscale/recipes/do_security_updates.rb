#
# Cookbook Name:: rightscale
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker

if "#{node[:rightscale][:security_updates]}" == "enable"
  platform =  node[:platform]
  log "  Applying secutiy updates for #{platform}"
  # Make sure we DON'T check the output of the update because it
  # may return a non-zero error code when one server is down but all
  # the others are up, and a partial update was successful!
  # If the upgrade fails then the security update monitor will
  # trigger alerting users to investigate what went wrong.
  case platform
  when "ubuntu"
    execute "apply apt security updates" do
      command "apt-get -y update && apt-get -y upgrade || true"
    end
    ruby_block "check and tag if reboot required" do
      block do
        if ::File.exists?("/var/run/reboot-required")
          system("rs_tag -a 'rs_monitoring:reboot_required=true'")
        else
          system("rs_tag -r 'rs_monitoring:reboot_required=true'")
        end
      end
    end
  when "centos", "redhat"
    # Update packages
    execute "apply yum security updates" do
      command "yum -y update || true"
    end
    ruby_block "check and tag if reboot is required" do
      block do
        uname_cmd = Mixlib::ShellOut.new("uname -r")
        uname_cmd.run_command
        uname_cmd.error!
        current_kernel_version = uname_cmd.stdout.chomp
        Chef::Log.info "Current Kernel Version: #{current_kernel_version}"

        rpm_cmd = Mixlib::ShellOut.new("rpm -q kernel | tail -1")
        rpm_cmd.run_command
        rpm_cmd.error!
        updated_kernel_version = rpm_cmd.stdout.chomp
        Chef::Log.info "Updated Kernel Version: #{updated_kernel_version}"
        if updated_kernel_version != current_kernel_version
          Chef::Log.info "Adding reboot required tag"
          add_tag_cmd = Mixlib::ShellOut.new(
            "rs_tag -a 'rs_monitoring:reboot_required=true'"
          )
          add_tag_cmd.run_command
          add_tag_cmd.error!
          Chef::Log.info add_tag_command.stdout
        else
          Chef::Log.info "Removing reboot required tag"
          remove_tag_cmd = Mixlib::ShellOut.new(
            "rs_tag -r 'rs_monitoring:reboot_required=true'"
          )
          remove_tag_cmd.run_command
          remove_tag_cmd.error!
          Chef::Log.info remove_tag_cmd.stdout
        end
      end
    end
  else
    log " Security updates not supported for platform #{platform}"
  end
else
  log "  Security updates disabled. Skipping update!"
end
