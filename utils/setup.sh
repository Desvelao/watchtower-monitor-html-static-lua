
# Fix problem compiling with `xml` dependency
SRC_XML_DIR=/tmp
CURRENT_DIR=$(pwd)

echo "CURRENT DIRECTORY: $CURRENT_DIR"
mkdir -p $SRC_XML_DIR
cd $SRC_XML_DIR
apk add git zlib-dev curl
git clone https://github.com/lubyk/xml xml_lua
cd xml_lua
git checkout REL-1.1.3
cp xml-1.1.3-1.rockspec xml-1.1.3-1.rockspec.bk
curl -L https://gist.githubusercontent.com/ossie-git/ffddb4fd619c93db6baa45b62a65b89b/raw/09cc71a13ed3c7e772e51bba01c0602b1e7504c8/xml-1.1.3-1.rockspec -o $SRC_XML_DIR/xml_lua/xml-1.1.3-1.rockspec

cd $CURRENT_DIR
luarocks install $SRC_XML_DIR/xml_lua/xml-1.1.3-1.rockspec
