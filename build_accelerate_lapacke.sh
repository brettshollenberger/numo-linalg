#!/bin/bash
set -e

# Define directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/ext/lapacke_build"
INSTALL_DIR="${SCRIPT_DIR}/ext/lapacke_install"
SRC_DIR="${BUILD_DIR}/src"

# Create directories
mkdir -p "${BUILD_DIR}"
mkdir -p "${SRC_DIR}"
mkdir -p "${INSTALL_DIR}"

# Clone the accelerate-lapacke repository
if [ ! -d "${BUILD_DIR}/accelerate-lapacke" ]; then
  echo "Cloning accelerate-lapacke repository..."
  git clone git@github.com:lepus2589/accelerate-lapacke.git "${BUILD_DIR}/accelerate-lapacke"
fi

# Navigate to the repository
cd "${BUILD_DIR}/accelerate-lapacke"

# Create a build directory
mkdir -p build
cd build

# Configure with CMake (standard approach instead of presets)
echo "Configuring with CMake..."
cmake .. \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_INDEX64=OFF

# Build
echo "Building LAPACKE..."
cmake --build . --verbose

# Install
echo "Installing LAPACKE..."
cmake --build . --verbose --target install

# Copy the alias files to our src directory
echo "Copying alias files..."
if [ -f "${BUILD_DIR}/accelerate-lapacke/build/src/new-lapack.alias" ]; then
  cp "${BUILD_DIR}/accelerate-lapacke/build/src/new-lapack.alias" "${SRC_DIR}/"
fi
if [ -f "${BUILD_DIR}/accelerate-lapacke/build/src/new-lapack-ilp64.alias" ]; then
  cp "${BUILD_DIR}/accelerate-lapacke/build/src/new-lapack-ilp64.alias" "${SRC_DIR}/"
fi

echo "Build completed successfully!"
echo "LAPACKE installed to: ${INSTALL_DIR}"
echo "Alias files copied to: ${SRC_DIR}"

# Create a README file with usage instructions
cat > "${INSTALL_DIR}/README.md" << EOF
# Custom LAPACKE for Apple Accelerate Framework

This directory contains a custom-built LAPACKE library that works with the Apple Accelerate framework.

## Usage

To use this library with Numo::Linalg, ensure that the library path is correctly set in your environment:

\`\`\`bash
export DYLD_LIBRARY_PATH="${INSTALL_DIR}/lib:\$DYLD_LIBRARY_PATH"
\`\`\`

Or you can specify the library path directly when installing Numo::Linalg:

\`\`\`bash
gem install numo-linalg -- --with-lapacke-dir="${INSTALL_DIR}"
\`\`\`

## Details

This LAPACKE library is built specifically to work with the Apple Accelerate framework on macOS. It uses symbol aliasing to map the Accelerate framework's LAPACK symbols to the standard LAPACK API.

For more information, see the [accelerate-lapacke](https://github.com/LDNN97/accelerate-lapacke) repository.
EOF

echo "README created at: ${INSTALL_DIR}/README.md"
