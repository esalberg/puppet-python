# == Class: python::install
#
# Installs core python packages,
#
# === Examples
#
# include python::install
#
# === Authors
#
# Sergey Stankevich
# Ashley Penney
# Fotis Gimian
# Garrett Honeycutt <code@garretthoneycutt.com>
#
class python::install {

  $local_scl_repo = $python::local_scl_repo

  $python = $::python::version ? {
    'system' => 'python',
    'pypy'   => 'pypy',
    default  => "${python::version}",
  }

  if $python::provider == 'rhscl' and $local_scl_repo {
    $pythondev = "${python}-python-devel"
  } else {
    $pythondev = $::osfamily ? {
      'RedHat' => "${python}-devel",
      'Debian' => "${python}-dev",
      'Suse'   => "${python}-devel",
    }
  }

  $dev_ensure = $python::dev ? {
    true    => 'present',
    false   => 'absent',
    default => $python::dev,
  }

  $scldev_ensure = $python::scldev ? {
    true    => 'present',
    false   => 'absent',
    default => $python::scldev,
  }

  if $python::provider == 'rhscl' and $local_scl_repo {
    $pip = "${python}-python-pip"
  } else {
    $pip = 'pip'
  }

  $pip_ensure = $python::pip ? {
    true    => 'present',
    false   => 'absent',
    default => $python::pip,
  }

  $scl_utils_ensure = $python::scl_utils ? {
    true    => 'present',
    false   => 'absent',
    default => $python::scl_utils,
  }

  $setuptools_ensure = $python::setuptools ? {
    true    => 'present',
    false   => 'absent',
    default => $python::setuptools,
  }

  $venv_ensure = $python::virtualenv ? {
    true    => 'present',
    false   => 'absent',
    default => $python::virtualenv,
  }

  package { 'python':
    ensure => $python::ensure,
    name   => $python,
  }

  package { 'virtualenv':
    ensure  => $venv_ensure,
    require => Package['python'],
  }

  case $python::provider {
    pip: {

      package { 'pip':
        ensure  => $pip_ensure,
        name    => $pip,
        require => Package['python'],
      }

      package { 'python-dev':
        ensure => $dev_ensure,
        name   => $pythondev,
      }

      # Install pip without pip, see https://pip.pypa.io/en/stable/installing/.
      exec { 'bootstrap pip':
        command => '/usr/bin/curl https://bootstrap.pypa.io/get-pip.py | python',
        creates => '/usr/local/bin/pip',
        require => Package['python'],
      }

      # Puppet is opinionated about the pip command name
      file { 'pip-python':
        ensure  => link,
        path    => '/usr/bin/pip-python',
        target  => '/usr/bin/pip',
        require => Exec['bootstrap pip'],
      }

      Exec['bootstrap pip'] -> File['pip-python'] -> Package <| provider == pip |>

      Package <| title == 'pip' |> {
        name     => 'pip',
        provider => 'pip',
      }
      Package <| title == 'virtualenv' |> {
        name     => 'virtualenv',
        provider => 'pip',
      }
    }
    scl: {
      # SCL is only valid in the RedHat family. If RHEL, package must be
      # enabled using the subscription manager outside of puppet. If CentOS,
      # the centos-release-SCL will install the repository.
      $install_scl_repo_package = $::operatingsystem ? {
        'CentOS' => 'present',
        default  => 'absent',
      }

      package { 'centos-release-scl':
        ensure => $install_scl_repo_package,
        before => Package['scl-utils'],
      }
      package { 'scl-utils':
        ensure => $scl_utils_ensure,
        before => Package['python'],
      }

      # This gets installed as a dependency anyway
      # package { "${python::version}-python-virtualenv":
      #   ensure  => $venv_ensure,
      #   require => Package['scl-utils'],
      # }
      package { "${python}-scldevel":
        ensure  => $dev_ensure,
        require => Package['scl-utils'],
      }
      if $pip_ensure != 'absent' and $setuptools_ensure != 'latest' {
        exec { 'python-scl-pip-install':
          command => "${python::exec_prefix}easy_install pip",
          path    => ['/usr/bin', '/bin'],
          creates => "/opt/rh/${python::version}/root/usr/bin/pip",
          require => Package['scl-utils'],
        }
      } elsif $pip_ensure != 'absent' and $setuptools_ensure == 'latest' {
        exec { 'python-scl-pip-install-setuptools-upgrade':
          command     => "${python::params::exec_prefix}easy_install pip; ${python::params::exec_prefix}easy_install -U setuptools",
          environment => ["LD_LIBRARY_PATH=/opt/rh/${python::version}/root/usr/lib64", "XDG_DATA_DIRS=/opt/rh/${python::version}/root/usr/share", "PKG_CONFIG_PATH=/opt/rh/${python::version}/root/usr/lib64/pkgconfig"],
          path        => ["/opt/rh/${python::version}/root/usr/bin", '/usr/bin', '/bin'],
          creates     => "/opt/rh/${python::version}/root/usr/bin/pip",
          require     => Package['scl-utils'],
        }
      }
    }

    rhscl: {
      if $local_scl_repo {
        package { 'scl-utils':
          ensure => $scl_utils_ensure,
          before => Package['python'],
          tag    => 'python-scl-repo',
        }
        
        package { 'pip':
          ensure  => $pip_ensure,
          name    => $pip,
          require => Package['python'],
        }
      } else {
        # rhscl is RedHat SCLs from softwarecollections.org
        $scl_package = "rhscl-${::python::version}-epel-${::operatingsystemmajrelease}-${::architecture}"
        package { $scl_package:
          source   => "https://www.softwarecollections.org/en/scls/rhscl/${::python::version}/epel-${::operatingsystemmajrelease}-${::architecture}/download/${scl_package}.noarch.rpm",
          provider => 'rpm',
          tag      => 'python-scl-repo',
        }
      }

      Package <| title == 'python' |> {
        tag => 'python-scl-package',
      }

      package { "${python}-scldevel":
        ensure => $scldev_ensure,
        tag    => 'python-scl-package',
      }

      package { 'python-dev':
        ensure => $dev_ensure,
        name   => $pythondev,
      }

      if $pip_ensure != 'absent' and !$local_scl_repo {
        exec { 'python-scl-pip-install':
          command => "${python::exec_prefix}easy_install pip",
          path    => ['/usr/bin', '/bin'],
          creates => "/opt/rh/${python::version}/root/usr/bin/pip",
        }
      }

      if $setuptools_ensure == 'latest' {
        exec { 'python-scl-setuptools-upgrade':
          command     => 'easy_install -U setuptools',
          environment => ["LD_LIBRARY_PATH=/opt/rh/${python}/root/usr/lib64", "XDG_DATA_DIRS=/opt/rh/${python}/root/usr/share", "PKG_CONFIG_PATH=/opt/rh/${python}/root/usr/lib64/pkgconfig"],
          path        => ["/opt/rh/${python}/root/usr/bin", '/usr/bin', '/bin'],
          require     => Package['scl-utils'],
          subscribe   => Package['python'],
          refreshonly => true,
          tag         => 'python-setuptools-update',
        }
      }

      if $pip_ensure != 'absent' and !$local_scl_repo {
        Package <| tag == 'python-scl-repo' |> ->
        Package <| tag == 'python-scl-package' |> ->
        Exec['python-scl-pip-install']
      } else {
          Package <| tag == 'python-scl-repo' |> ->
          Package <| tag == 'python-scl-package' |>
      }
    }

    default: {

      package { 'pip':
        ensure  => $pip_ensure,
        require => Package['python'],
      }

      package { 'python-dev':
        ensure => $dev_ensure,
        name   => $pythondev,
      }

      if $::osfamily == 'RedHat' {
        if $pip_ensure != 'absent' {
          if $python::use_epel == true {
            include 'epel'
            Class['epel'] -> Package['pip']
          }
        }
        if ($venv_ensure != 'absent') and ($::operatingsystemrelease =~ /^6/) {
          if $python::use_epel == true {
            include 'epel'
            Class['epel'] -> Package['virtualenv']
          }
        }

        $virtualenv_package = "${python}-virtualenv"
      } else {
        $virtualenv_package = $::lsbdistcodename ? {
          'jessie' => 'virtualenv',
          default  => 'python-virtualenv',
        }
      }

      if $::python::version =~ /^3/ {
        $pip_package = 'python3-pip'
      } else {
        $pip_package = 'python-pip'
      }

      Package <| title == 'pip' |> {
        name => $pip_package,
      }

      Package <| title == 'virtualenv' |> {
        name => $virtualenv_package,
      }
    }
  }

  if $python::manage_gunicorn {
    $gunicorn_ensure = $python::gunicorn ? {
      true    => 'present',
      false   => 'absent',
      default => $python::gunicorn,
    }

    package { 'gunicorn':
      name   => $python::gunicorn_package_name,
      ensure => $gunicorn_ensure,
    }
  }
}
