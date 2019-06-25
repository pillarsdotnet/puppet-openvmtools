# == Class: openvmtools
#
# This class handles installing the Open Virtual Machine Tools.
#
# === Parameters:
#
# [*ensure*]
#   Ensure if present or absent.
#   Default: present
#
# [*autoupgrade*]
#   Upgrade package automatically, if there is a newer version.
#   Default: false
#
# [*desktop_package_name*]
#   Name of the desktop package.
#   Only set this if your platform is not supported or you know what you are
#   doing.
#   Default: auto-set, platform specific
#
# [*manage_epel*]
#   Boolean that determines if stahnma-epel is required for packages.
#   This should only needed for RedHat (EL) 6.
#
# [*package_name*]
#   Name of the package.
#   Only set this if your platform is not supported or you know what you are
#   doing.
#   Default: auto-set, platform specific
#
# [*service_ensure*]
#   Ensure if service is running or stopped.
#   Default: running
#
# [*service_enable*]
#   Start service at boot.
#   Default: true
#
# [*service_hasstatus*]
#   Service has status command.
#   Only set this if your platform is not supported or you know what you are
#   doing.
#   Default: auto-set, platform specific
#
# [*service_name*]
#   Name(s) of openvmtools service(s).
#   Only set this if your platform is not supported or you know what you are
#   doing.
#   Default: auto-set, platform specific
#
# [*service_pattern*]
#   Pattern to look for in the process table to determine if the daemon is
#   running.
#   Only set this if your platform is not supported or you know what you are
#   doing.
#   Default: vmtoolsd
#
# [*with_desktop*]
#   Whether or not to install the desktop/GUI support.
#   Default: false
#
# === Sample Usage:
#
#   include openvmtools
#
# === Authors:
#
# Originally written by Mike Arnold <mike@razorsedge.org>
# Transferred to Vox Pupuli <voxpupuli@groups.io>
#
# === Copyright:
#
# Copyright (C) 2017 Vox Pupuli
#
class openvmtools (
  Enum['absent','present']            $ensure                    = 'present',
  Boolean                             $autoupgrade               = false,
  Boolean                             $desktop_package_conflicts = false,
  String[1]                           $desktop_package_name      = 'open-vm-tools-desktop',
  Boolean                             $manage_epel               = false,
  String[1]                           $package_name              = 'open-vm-tools',
  Stdlib::Ensure::Service             $service_ensure            = 'running',
  Variant[String[1],Array[String[1]]] $service_name              = ['vgauthd','vmtoolsd'],
  Boolean                             $service_enable            = true,
  Boolean                             $service_hasstatus         = true,
  String[1]                           $service_pattern           = 'vmtoolsd',
  Boolean                             $supported                 = false,
  Boolean                             $with_desktop              = false,
) {

  if $ensure == 'present' {
    $package_ensure = $autoupgrade ? {
      true    => 'latest',
      default => 'present',
    }
    $service_ensure_real = $service_ensure
  } else {  # ensure == 'absent'
    $package_ensure = 'absent'
    $service_ensure_real = 'stopped'
  }

  if $facts['virtual'] == 'vmware' {
    notify { 'vmware host found': message => 'vmware host found' }
    if $supported {
      notify { 'supported operating system': message => 'supported operating system' }
      $packages = $with_desktop ? {
        true    => $desktop_package_conflicts ? {
          true    => [ $desktop_package_name ],
          default => [ $package_name, $desktop_package_name ],
        },
        default => [ $package_name ],
      }
      notify { 'packages': message => '$packages = [%s]'.sprintf($packages.join(',')) }

      if $manage_epel {
        notify { 'including epel': message => 'including epel' }
        include epel
        Yumrepo['epel'] -> Package[$package_name]
      }

      if $facts['vmware_uninstaller'] =~ Stdlib::Unixpath {
        notify { 'Found uninstaller': message => 'Found %s'.sprintf($facts['vmware_uninstaller']) }
        $vmware_lib = $facts['vmware_uninstaller'].regex_replace(
          'bin/vmware-uninstall-tools.pl',
          'lib/vmware-tools'
        )
        exec { 'vmware-uninstall-tools':
          command => "${facts['vmware_uninstaller']} && rm -rf ${vmware_lib}",
          before  => Package['VMwareTools'],
        }
      }

      notify { 'Ensuring package VMwareTools is absent.': message => 'Ensuring package VMwareTools is absent.' }
      package { 'VMwareTools':
        ensure  => 'absent',
        before  => Package[$packages],
      }

      notify { 'Ensuring packages': message => 'Ensuring [%s] are %s'.sprintf($packages.join(','),$package_ensure) }
      package { $packages:
        ensure => $package_ensure,
      }

      [$service_name].flatten.each |$name| {
        notify { 'Ensuring service': message => 'Ensuring service %s is %s'.sprintf($name,$service_ensure_real) }
      }
      service { $service_name:
        ensure    => $service_ensure_real,
        enable    => $service_enable,
        hasstatus => $service_hasstatus,
        pattern   => $service_pattern,
        require   => Package[$packages],
      }

    } else {  # $supported == false
      notify { 'unsupported': message => "Your operating system ${facts['os']['name']} \
         ${facts['os']['release']['full']} is unsupported and will not have the \
         Open Virtual Machine Tools installed." }
    }
  }  # $facts['virtual'] == 'vmware'
  else {
    notify{ 'Not a vmware host': message => 'Not a vmware host' }
  }
}
