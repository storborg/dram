from __future__ import print_function

from setuptools import setup, find_packages


setup(name='dram',
      version='0.0.1.dev',
      description='Keeping your Package Manager Packaged',
      long_description='',
      classifiers=[
          'Development Status :: 2 - Pre-Alpha',
          'License :: OSI Approved :: MIT License',
      ],
      keywords='shell macports homebrew software dependencies package manager',
      url='https://github.com/storborg/dram',
      author='Scott Torborg',
      author_email='storborg@gmail.com',
      # Don't require six newer than this, el capitan will hate you.
      install_requires=['six>=1.4.1'],
      license='MIT',
      packages=find_packages(),
      test_suite='nose.collector',
      tests_require=['nose'],
      include_package_data=True,
      zip_safe=False,
      entry_points="""\
      [console_scripts]
      dram-install = dram:install
      """)
