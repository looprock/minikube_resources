#!/usr/bin/env python
# dumb example service
import bottle
import os
listenaddr = os.environ.get('listenaddr', '0.0.0.0')
listenport = os.environ.get('listenport', '8080')
app = bottle.Bottle()
@app.route('/')
def hi():
    return "hi"

bug=True
if __name__ == '__main__':
    try:
        app.run(host=listenaddr, port=listenport, debug=bug)
    except KeyboardInterrupt:
        sys.exit("Aborted by Ctrl-C!")
