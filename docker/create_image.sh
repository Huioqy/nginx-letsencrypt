VERSION=1.0.0
if [[ ! -z $VERSION ]]; then
    docker build --rm -t huioqy/nginx-letsencrypt:$VERSION .
else
    echo "Error: You need to specify a version as first argument"
fi
