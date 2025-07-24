cat > install-license-setup.sh <<'EOL'
#!/bin/bash

# ساخت پوشه‌ها
mkdir -p docker scripts licenses

# ساخت اسکریپت Bash
cat > scripts/generate-licenses.sh <<'SCRIPT'
#!/bin/bash

NAME="Mohammad Reza Jalili Rad"
YEAR="2025-2027"
OUTPUT_DIR="licenses"

mkdir -p $OUTPUT_DIR

# MIT License
cat > $OUTPUT_DIR/LICENSE-MIT <<LICENSE
MIT License

Copyright (c) $YEAR $NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LICENSE

# Apache License
cat > $OUTPUT_DIR/LICENSE-APACHE <<LICENSE
Apache License
Version 2.0, January 2004
Copyright (c) $YEAR $NAME

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
LICENSE

# GPL License
cat > $OUTPUT_DIR/LICENSE-GPL <<LICENSE
GNU GENERAL PUBLIC LICENSE
Version 3, 29 June 2007
Copyright (c) $YEAR $NAME

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
LICENSE

echo "✅ سه لایسنس ساخته شد (MIT, Apache 2.0, GPL 3.0) در پوشه $OUTPUT_DIR/"
SCRIPT
chmod +x scripts/generate-licenses.sh

# Dockerfile
cat > docker/Dockerfile <<'DOCKER'
FROM alpine:3.18
RUN apk add --no-cache bash
WORKDIR /app
COPY ../scripts/generate-licenses.sh /app/generate-licenses.sh
RUN chmod +x /app/generate-licenses.sh
ENTRYPOINT ["/app/generate-licenses.sh"]
DOCKER

# افزودن اسکریپت‌ها به package.json
if grep -q '"scripts":' package.json; then
  sed -i '/"scripts": {/a \    "gen:licenses": "bash scripts/generate-licenses.sh",\n    "gen:licenses:docker": "docker build -t license-gen ./docker && docker run --rm -v $(pwd):/app license-gen",' package.json
else
  echo '"scripts": {
    "gen:licenses": "bash scripts/generate-licenses.sh",
    "gen:licenses:docker": "docker build -t license-gen ./docker && docker run --rm -v $(pwd):/app license-gen"
  }' >> package.json
fi

# Commit و Push
git add .
git commit -m "Added license generator (MIT, Apache 2.0, GPL 3.0) with Yarn & Docker support"
git push

echo "✅ تنظیمات کامل نصب شد و به مخزن اضافه شد!"
EOL

chmod +x install-license-setup.sh
