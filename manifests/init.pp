# == Class: python
#
# Installs and manages python, python-dev, python-virtualenv and Gunicorn.
#
# === Parameters
#
# [*ensure*]
#  Desired installation state for the Python package. Valid options are absent,
#  present and latest. Default: present
#
# [*local_rhscl_repo*]
# Define whether we are using a local SCL repo or the default internet one.
# Default: false
#
# [*version*]
#  Python version to install. Beware that valid values for this differ a) by
#  the provider you choose and b) by the osfamily/operatingsystem you are using.
#  Default: system default
#  Allowed values:
#   - provider == pip: everything pip allows as a version after the 'python=='
#   - else: 'system', 'pypy', 3/3.3/...
#      - Be aware that 'system' usually means python 2.X.
#      - 'pypy' actually lets us use pypy as python.
#      - 3/3.3/... means you are going to install the python3/python3.3/...
#        package, if available on your osfamily.
#
# [*pip*]
#  Desired installation state for python-pip. Boolean values are deprecated.
#  Default: present
#  Allowed values: 'absent', 'present', 'latest'
#
# [*dev*]
#  Desired installation state for python-dev. Boolean values are deprecated.
#  Default: absent
#  Allowed values: 'absent', 'present', 'latest'
#
# [*scldev*]
#  Desired installation state for python-scldev. Boolean values are deprecated.
#  Default: absent
#  Allowed values: 'absent', 'present', 'latest'
#
# [*scl_utils*]
#  Desired installation state for scl_utils (scl or rhscl provider).
#  Valid options are absent, present and latest.
#  Default: latest
#
# [*setuptools*]
#  Desired installation state for setuptools. Often installed by default.
#  Default: present
#  Allowed values: 'absent', 'present', 'latest'
#
# [*virtualenv*]
#  Desired installation state for python-virtualenv. Boolean values are
#  deprecated. Default: absent
#  Allowed values: 'absent', 'present', 'latest
#
# [*gunicorn*]
#  Desired installation state for Gunicorn. Boolean values are deprecated.
#  Default: absent
#  Allowed values: 'absent', 'present', 'latest'
#
# [*manage_gunicorn*]
#  Allow Installation / Removal of Gunicorn. Default: true
#
# [*provider*]
#  What provider to use for installation of the packages, except gunicorn and
#  Python itself. Default: system default provider
#  Allowed values: 'pip','scl','rhscl'
#
# [*use_epel*]
#  Boolean to determine if the epel class is used. Default: true
#
# === Examples
#
# class { 'python':
#   version    => 'system',
#   pip        => 'present',
#   dev        => 'present',
#   virtualenv => 'present',
#   gunicorn   => 'present',
# }
#
# === Authors
#
# Sergey Stankevich
# Garrett Honeycutt <code@garretthoneycutt.com>
#
class python (
  $ensure                    = $python::params::ensure,
  $scl_utils                 = $python::params::scl_utils,
  $local_scl_repo            = $python::params::local_scl_repo,
  $version                   = $python::params::version,
  $pip                       = $python::params::pip,
  $dev                       = $python::params::dev,
  $scldev                    = $python::params::scldev,
  $setuptools                = $python::params::setuptools,
  $virtualenv                = $python::params::virtualenv,
  $gunicorn                  = $python::params::gunicorn,
  $manage_gunicorn           = $python::params::manage_gunicorn,
  $gunicorn_package_name     = $python::params::gunicorn_package_name,
  $provider                  = $python::params::provider,
  $valid_versions            = $python::params::valid_versions,
  $python_pips               = { },
  $python_virtualenvs        = { },
  $python_pyvenvs            = { },
  $python_requirements       = { },
  $use_epel                  = $python::params::use_epel,
) inherits python::params{

  if $provider != undef and $provider != '' {
    validate_re($provider, ['^(pip|scl|rhscl)$'],
      "Only 'pip', 'rhscl' and 'scl' are valid providers besides the system default. Detected provider is <${provider}>.")
  }

  $exec_prefix = $provider ? {
    'scl'   => "scl enable ${version} -- ",
    'rhscl' => "scl enable ${version} -- ",
    default => '',
  }

  validate_re($ensure, ['^(absent|present|latest)$'])
  validate_re($version, concat(['system', 'pypy'], $valid_versions))

  if $pip == false or $pip == true {
    warning('Use of boolean values for the $pip parameter is deprecated')
  } else {
    validate_re($pip, ['^(absent|present|latest)$'])
  }

  if $dev == false or $dev == true {
    warning('Use of boolean values for the $dev parameter is deprecated')
  } else {
    validate_re($dev, ['^(absent|present|latest)$'])
  }

  if $scldev == false or $scldev == true {
    warning('Use of boolean values for the $scldev parameter is deprecated')
  } else {
    validate_re($scldev, ['^(absent|present|latest)$'])
  }

  if $scl_utils == false or $scl_utils == true {
    warning('Use of boolean values for the $scl_utils parameter is deprecated')
  } else {
    validate_re($scl_utils, ['^(absent|present|latest)$'])
  }

  if $setuptools == false or $setuptools == true {
    warning('Use of boolean values for the $setuptools parameter is deprecated')
  } else {
    validate_re($setuptools, ['^(absent|present|latest)$'])
  }

  if $virtualenv == false or $virtualenv == true {
    warning('Use of boolean values for the $virtualenv parameter is deprecated')
  } else {
    validate_re($virtualenv, ['^(absent|present|latest)$'])
  }

  if $gunicorn == false or $gunicorn == true {
    warning('Use of boolean values for the $gunicorn parameter is deprecated')
  } else {
    validate_re($gunicorn, ['^(absent|present|latest)$'])
  }

  validate_bool($manage_gunicorn)
  validate_bool($use_epel)

  # Module compatibility check
  $compatible = [ 'Debian', 'RedHat', 'Suse' ]
  if ! ($::osfamily in $compatible) {
    fail("Module is not compatible with ${::operatingsystem}")
  }

  # Anchor pattern to contain dependencies
  anchor { 'python::begin': } ->
  class { 'python::install': } ->
  class { 'python::config': } ->
  anchor { 'python::end': }

  # Allow hiera configuration of python resources
  create_resources('python::pip', $python_pips)
  create_resources('python::pyvenv', $python_pyvenvs)
  create_resources('python::virtualenv', $python_virtualenvs)
  create_resources('python::requirements', $python_requirements)

}
