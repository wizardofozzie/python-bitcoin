# === makefile ------------------------------------------------------------===
# Copyright © 2012 by its contributors. See AUTHORS for details.
#
# Distributed under the MIT/X11 software license, see the accompanying
# file LICENSE or http://www.opensource.org/licenses/mit-license.php.
# ===----------------------------------------------------------------------===

ROOT=$(shell pwd)
CACHE_ROOT=${ROOT}/.cache
PKG_ROOT=${ROOT}/.pkg

-include Makefile.local

.PHONY: all
all: ${PKG_ROOT}/.stamp-h

http://sourceforge.net/projects/bitcoin/files/Bitcoin/testnet-in-a-box/testnet3-box.zip/download

.PHONY: check-data
check-data: tests/data/blk0001.dat
tests/data/blk0001.dat: ${CACHE_ROOT}/testnet3/testnet3-box.zip
	mkdir -p tests/data
	rm -f tests/data/blk0001.dat
	unzip -d tests/data -j ${CACHE_ROOT}/testnet3/testnet3-box.zip \
	    testnet-box/1/testnet3/blk0001.dat

.PHONY: check
check: all check-data
	mkdir -p build/report/xunit
	@echo  >.pytest.py "import unittest2"
	@echo >>.pytest.py "import xmlrunner"
	@echo >>.pytest.py "unittest2.main("
	@echo >>.pytest.py "    testRunner=xmlrunner.XMLTestRunner("
	@echo >>.pytest.py "        output='build/report/xunit'),"
	@echo >>.pytest.py "    argv=['unit2', 'discover',"
	@echo >>.pytest.py "        '-s','bitcoin',"
	@echo >>.pytest.py "        '-p','*.py',"
	@echo >>.pytest.py "        '-t','.',"
	@echo >>.pytest.py "    ]"
	@echo >>.pytest.py ")"
	chmod +x .pytest.py
	"${PKG_ROOT}"/bin/coverage run .pytest.py || { rm -f .pytest.py; exit 1; }
	"${PKG_ROOT}"/bin/coverage xml --omit=".pytest.py" -o build/report/coverage.xml
	rm -f .pytest.py

.PHONY: debugcheck
debugcheck: all
	mkdir -p build/report/xunit
	@echo  >.pytest.py "import unittest2"
	@echo >>.pytest.py "import xmlrunner"
	@echo >>.pytest.py "import exceptions, ipdb, sys"
	@echo >>.pytest.py "class PDBAssertionError(exceptions.AssertionError):"
	@echo >>.pytest.py "    def __init__(self, *args):"
	@echo >>.pytest.py "        exceptions.AssertionError.__init__(self, *args)"
	@echo >>.pytest.py "        print 'Assertion failed, entering PDB...'"
	@echo >>.pytest.py "        if hasattr(sys, '_getframe'):"
	@echo >>.pytest.py "            ipdb.set_trace(sys._getframe().f_back.f_back.f_back)"
	@echo >>.pytest.py "        else:"
	@echo >>.pytest.py "            ipdb.set_trace()"
	@echo >>.pytest.py "unittest2.TestCase.failureException = PDBAssertionError"
	@echo >>.pytest.py "unittest2.main("
	@echo >>.pytest.py "    testRunner=xmlrunner.XMLTestRunner("
	@echo >>.pytest.py "        output='build/report/xunit'),"
	@echo >>.pytest.py "    argv=['unit2', 'discover',"
	@echo >>.pytest.py "        '-s','bitcoin',"
	@echo >>.pytest.py "        '-p','*.py',"
	@echo >>.pytest.py "        '-t','.',"
	@echo >>.pytest.py "    ]"
	@echo >>.pytest.py ")"
	@chmod +x .pytest.py
	"${PKG_ROOT}"/bin/coverage run .pytest.py || { rm -f .pytest.py; exit 1; }
	"${PKG_ROOT}"/bin/coverage xml --omit=".pytest.py" -o build/report/coverage.xml
	rm -f .pytest.py

.PHONY: shell
shell: all
	"${PKG_ROOT}"/bin/ipython

.PHONY: mostlyclean
mostlyclean:
	-rm -rf dist
	-rm -rf build
	-rm -rf .coverage

.PHONY: clean
clean: mostlyclean
	-rm -rf "${PKG_ROOT}"

.PHONY: distclean
distclean: clean
	-rm -rf "${CACHE_ROOT}"
	-rm -rf Makefile.local

.PHONY: maintainer-clean
maintainer-clean: distclean
	@echo 'This command is intended for maintainers to use; it'
	@echo 'deletes files that may need special tools to rebuild.'

.PHONY: dist
dist:
	"${PKG_ROOT}"/bin/python setup.py sdist

# ===--------------------------------------------------------------------===

SOURCEFORGE_MIRROR := hivelocity.dl.sourceforge.net

${CACHE_ROOT}/virtualenv/virtualenv-1.8.2.tar.gz:
	mkdir -p ${CACHE_ROOT}/virtualenv
	sh -c "cd ${CACHE_ROOT}/virtualenv && curl -O http://pypi.python.org/packages/source/v/virtualenv/virtualenv-1.8.2.tar.gz"

${CACHE_ROOT}/numpy/numpy-1.6.2.tar.gz:
	mkdir -p "${CACHE_ROOT}"/numpy
	sh -c "cd "${CACHE_ROOT}"/numpy && curl -O 'http://pypi.python.org/packages/source/n/numpy/numpy-1.6.2.tar.gz'"

${CACHE_ROOT}/scipy/scipy-0.10.1.tar.gz:
	mkdir -p "${CACHE_ROOT}"/scipy
	sh -c "cd "${CACHE_ROOT}"/scipy && curl -O 'http://pypi.python.org/packages/source/s/scipy/scipy-0.10.1.tar.gz'"

${CACHE_ROOT}/testnet3/testnet3-box.zip:
	mkdir -p "${CACHE_ROOT}"/testnet3
	sh -c "cd "${CACHE_ROOT}"/testnet3 && curl -O 'http://$(SOURCEFORGE_MIRROR)/project/bitcoin/Bitcoin/testnet-in-a-box/testnet3-box.zip'"

${PKG_ROOT}/.stamp-h: conf/requirements*.pip ${CACHE_ROOT}/virtualenv/virtualenv-1.8.2.tar.gz ${CACHE_ROOT}/numpy/numpy-1.6.2.tar.gz ${CACHE_ROOT}/scipy/scipy-0.10.1.tar.gz
	# Because build and run-time dependencies are not thoroughly tracked,
	# it is entirely possible that rebuilding the development environment
	# on top of an existing one could result in a broken build. For the
	# sake of consistency and preventing unnecessary, difficult-to-debug
	# problems, the entire development environment is rebuilt from scratch
	# everytime this make target is selected.
	${MAKE} clean
	
	# The `${PKG_ROOT}` directory, if it exists, is removed by the
	# `clean` target. The PyPI cache is nonexistant if this is a freshly
	# checked-out repository, or if the `distclean` target has been run.
	# This might cause problems with build scripts executed later which
	# assume their existence, so they are created now if they don't
	# already exist.
	mkdir -p "${PKG_ROOT}"
	mkdir -p "${CACHE_ROOT}"/pypi
	
	# `virtualenv` is used to create a separate Python installation for
	# this project in `${PKG_ROOT}`.
	tar \
	    -C "${CACHE_ROOT}"/virtualenv --gzip \
	    -xf "${CACHE_ROOT}"/virtualenv/virtualenv-1.8.2.tar.gz
	python "${CACHE_ROOT}"/virtualenv/virtualenv-1.8.2/virtualenv.py \
	    --clear \
	    --distribute \
	    --never-download \
	    --prompt="(python-bitcoin) " \
	    "${PKG_ROOT}"
	-rm -rf "${CACHE_ROOT}"/virtualenv/virtualenv-1.8.2
	
	# M2Crypto is installed by easy_install so that we can fetch a binary
	# install, which might have configuration options to perform better on
	# a wider variety of targets. readline is installed here to get around
	# a bug on Mac OS X which is causing readline to not build properly if
	# installed from pip.
	"${PKG_ROOT}"/bin/easy_install M2Crypto
	"${PKG_ROOT}"/bin/easy_install readline
	
	tar \
	  -C "${CACHE_ROOT}"/numpy --gzip \
	  -xf "${CACHE_ROOT}"/numpy/numpy-1.6.2.tar.gz
	bash -c " \
	  source '${PKG_ROOT}'/bin/activate; \
	  if [ \"x`uname -s`\" == \"xDarwin\" ]; then \
	    if [ -x /usr/bin/clang ]; then \
	      export CC=/usr/bin/clang; \
	      export CXX=/usr/bin/clang; \
	    else \
	      export CC=/usr/bin/gcc-4.0; \
	      export CXX=/usr/bin/g++-4.0; \
	    fi; \
	    if [ \"x`uname -s -r`\" == \"xDarwin 11.3.0\" ]; then \
	      export FFLAGS=-ff2c; \
	    fi; \
	  elif [ \"x`uname -s`\" == \"xLinux\" ]; then \
	    export BLAS=/usr/lib64/libblas.so; \
	    export LAPACK=/usr/lib64/liblapack.so; \
	  fi; \
	  cd '${CACHE_ROOT}'/numpy/numpy-1.6.2; \
	  python setup.py build && \
	  python setup.py install"
	-rm -rf "${CACHE_ROOT}"/numpy/numpy-1.6.2
	
	tar \
	  -C "${CACHE_ROOT}"/scipy --gzip \
	  -xf "${CACHE_ROOT}"/scipy/scipy-0.10.1.tar.gz
	bash -c " \
	  source '${PKG_ROOT}'/bin/activate; \
	  if [ \"x`uname -s`\" == \"xDarwin\" ]; then \
	    if [ -x /usr/bin/clang ]; then \
	      export CC=/usr/bin/clang; \
	      export CXX=/usr/bin/clang; \
	    else \
	      export CC=/usr/bin/gcc-4.0; \
	      export CXX=/usr/bin/g++-4.0; \
	    fi; \
	    if [ \"x`uname -s -r`\" == \"xDarwin 11.3.0\" ]; then \
	      export FFLAGS=-ff2c; \
	    fi; \
	  elif [ \"x`uname -s`\" == \"xLinux\" ]; then \
	    export BLAS=/usr/lib64/libblas.so; \
	    export LAPACK=/usr/lib64/liblapack.so; \
	  fi; \
	  cd '${CACHE_ROOT}'/scipy/scipy-0.10.1; \
	  python setup.py build && \
	  python setup.py install"
	-rm -rf "${CACHE_ROOT}"/scipy/scipy-0.10.1
	
	# pip is used to install Python dependencies for this project.
	for reqfile in conf/requirements*.pip; do \
	    CFLAGS=-I/opt/local/include LDFLAGS=-L/opt/local/lib \
	    "${PKG_ROOT}"/bin/python "${PKG_ROOT}"/bin/pip install \
	        --download-cache="${CACHE_ROOT}"/pypi \
	        -r $$reqfile; \
	done
	
	# All done!
	touch "${PKG_ROOT}"/.stamp-h

# ===--------------------------------------------------------------------===
# End of File
# ===--------------------------------------------------------------------===
