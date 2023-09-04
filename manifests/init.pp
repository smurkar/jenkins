class jenkins (

  Integer $jenkins_port = 8000
)
{

  $osver = $::facts['os']['family']
  $param = {
    'jenkins_port' => $jenkins_port,
  }

  case $::facts['os']['family'] {

    "RedHat": {
      $package_jdk = 'java-17-openjdk'
      $package_repo = '/etc/yum.repos.d/jenkins.repo'
      $jenkins_key = 'rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key'
      $jenkis_config =  '/usr/lib/systemd/system/jenkins.service'
      $firewall_task = "firewall-cmd --add-port=${jenkins_port}/tcp --permanent && firewall-cmd --reload"
    }

    "Debian": {
      $package_jdk = 'openjdk-17-jre'
      $package_repo = '/etc/apt/sources.list.d/jenkins.list'
      $jenkins_key = 'curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null && apt-get update'
      $jenkis_config =  '/lib/systemd/system/jenkins.service'
      $firewall_task = "ufw allow ${jenkins_port}"
    }

    default: {
      notify { "Unknown operating system":
      }
    }

  }

  if $osver == 'RedHat' or $osver == 'Debian' {
    package { $package_jdk :
      ensure => installed,
    }

    file { $package_repo :
      ensure => file,
      source => "puppet:///modules/jenkins/${osver}",
      notify => Exec['Jenkins key install'],
    }

    exec { 'Jenkins key install' :
      path => '/usr/bin:/usr/sbin:/bin',
      command => $jenkins_key,
      refreshonly => true,
    }

    package { 'jenkins' :
      ensure => installed,
      notify => Exec['Firewall Add'],
    }

    exec { 'Firewall Add':
      path => '/usr/bin:/usr/sbin:/bin',
      command => $firewall_task,
      refreshonly => true,
    }
    file { $jenkis_config :
      ensure => file,
      content => epp("jenkins/jenkins_service.epp", $param),
      notify => Exec['systemctl daemon-reload'],
    }

    exec { 'systemctl daemon-reload' :
      path => '/usr/bin:/usr/sbin:/bin',
      refreshonly => true,
    }

    service { 'jenkins' :
      ensure => running,
      enable => true,
      subscribe => File[ $jenkis_config ],
    }
  }
}
