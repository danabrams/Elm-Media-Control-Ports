const MediaControl = {
    setup:
        function (app) {
            if (app.ports) {
                //has the user properly created a toJs port (or installed ours)?
                if (app.ports.toJs) {
                    app.ports.toJs.subscribe(respondToElm);
                }
            }
            //Install the video custom element.
            customElements.define("video-element", VideoElement);
        }
};

//Elm can't decode a TimeRange object so we do so here and send back as an Array.
function decodeTimeRanges(ranges) {
    var decoded = [];
    if (ranges instanceof TimeRanges) {
        for (let i = 0; i < ranges.length; i++) {
            decoded.push({ start: ranges.start(i), end: ranges.end(i) });
        }
    }
    return decoded;
}

function errorToPortState(err) {
    return {
        result: "ERROR",
        data: err
    };
}

//for decoding our MediaElement's current state
function mediaToPortState(md) {
    return {
        result: "OK",
        currentTime: md.currentTime,
        duration: md.duration,
        playback: decodePlaybackState(md),
        loop: md.loop,
        muted: md.muted,
        source: md.src,
        volume: md.volume,
        playbackRate: md.playbackRate,
        readyState: md.readyState,
        networkState: md.networkState,
        width: md.videoWidth,
        height: md.videoHeight,
        seekable: decodeTimeRanges(md.seekable),
        buffered: decodeTimeRanges(md.buffered),
        played: decodeTimeRanges(md.played),
        error: ""
    };
}



//HELPER FUNCTIONS
function ok(result) {
    return { result: "OK", data: result };
}

function err(result) {
    return { result: "ERR", data: result };
}

function commandResult(result) {
    if (app.ports.commandResult) {
        app.ports.commandResult.send(result);
    }
}


function respondToElm(msg) {
    switch (msg.command) {
        case "CREATE":
            //before we do anything, make sure the proper port is installed.
            if (app.ports.mediaCreated.send) {
                let media = createMedia(msg.data);
                if (media != null) {
                    media.addEventListener('error', function () {
                        console.log('error ', media.error);
                        app.ports.mediaCreated.send(err(media.error));
                    });
                    media.addEventListener('loadmetadata', function () {
                        console.log('loadedmetadata ', media.src);
                        app.ports.mediaCreated.send(ok(media));
                    });
                    media.load();

                } else {
                    app.ports.mediaCreated.send(err("COULDNT_CREATE_MEDIA"));
                }
            }
            break;

        case "CHANGE_SETTING":
            if (msg.data.mediaObj) {
                switch (msg.data.setting) {
                    case "PLAY":
                        try {
                            msg.data.mediaObj.play();
                            commandResult(ok());
                        } catch (error) {
                            commandResult(err(error.message));
                        }
                        break;
                    case "PAUSE":
                        try {
                            msg.data.mediaObj.pause();
                            commandResult(ok());
                        } catch (error) {
                            commandResult(err(error.message));
                        }
                        break;
                    default:
                        try {
                            msg.data.mediaObj[msg.data.setting] = msg.data.value;
                            commandResult(ok());
                        } catch (error) {
                            commandResult(err(Error.message));
                        }
                        break;
                }
                //Make sure the right port is intalled, and if it is, send the current state through.
                if (app.ports.stateUpdate) {
                    app.ports.stateUpdate.send(mediaToPortState(msg.data.mediaObj));
                }
            }
        case "GET_STATE":
            //make sure the mediaObj is valid and the port exists.
            if (msg.data.mediaObj && app.ports.stateUpdate) {
                app.ports.stateUpdate.send(mediaToPortState(msg.data.mediaObj));
            }
            break;
        default:
            break;

    }
}

function decodePlaybackState(med) {
    if (med.paused == true) {
        return "PAUSED";
    } else {
        if (med.err) {
            return med.err.message;
        } else if (med.ended) {
            return "ENDED";
        } else if (med.readyState < 0) {
            return "LOADING";
        } else if (med.readyState == 2) {
            return "BUFFERING";
        } else {
            return "PLAYING";
        }
    }
}


function createUrlSource(src) {
    let urlSource = document.createElement("source");
    urlSource.setAttribute("src", src.url);
    if (src.type) {
        urlSource.setAttribute("type", (typeToString(src)));
    }
    return urlSource;
}

function typeToString(src) {
    var t = "";
    if (src.type) {
        t = src.type;
        if (src.codecs) {
            t = t + ";codecs=\"" + src.codecs + "\"";
        }
    }
    return t;
}

function createMedia(config) {
    let media = document.createElement("video");

    media.addEventListener('loadedmetadata', function () {
        app.ports.mediaCreated.send(ok(media));
    });

    //Is Elm providing us a single URL for our media?
    if (config.source.url) {
        let urlSource = createUrlSource(config.source);
        urlSource.onerror = function (error) {
            console.log("load error ", urlSource.error);
            app.ports.mediaCreated.send(err("NO_VALID_SOURCE_LOADED"));
        };
        media.appendChild(urlSource);
        //Or is elm providing a list of fallback URLs
    } else if (config.source.urls) {
        console.log(config.source.urls);
        let urlSource;
        let loadErrors = 0;
        for (let i = 0; i < config.source.urls.length; i++) {
            urlSource = createUrlSource(config.source.urls[i]);
            urlSource.onerror = function (error) {
                console.log("load error");
                loadErrors++;
                if (loadErrors == config.source.urls.length) {
                    app.ports.mediaCreated.send(err("NO_VALID_SOURCE_LOADED"))
                }
            };
            media.appendChild(urlSource);
        }
        //Or is elm asking us to create a Capture Stream.
    } else if (config.source.captureStream) {
        navigator.mediaDevices.getUserMedia = navigator.mediaDevices.getUserMedia || navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia;

        if (!navigator.mediaDevices.getUserMedia) {
            return { error: "USER_MEDIA_NOT_SUPPORTED" };
        }

        setTimeout(function () { return { error: "USER_APPROVAL_TIMEOUT" }; }, 60000);
        navigator.mediaDevices.getUserMedia(config.source.captureStream)
            .then(function (stream) {
                try {
                    media.srcObject = stream;
                } catch (error) {
                    console.log(error);
                    media.src = URL.createObjectURL(stream);
                }
                media.play();
            }).catch(function (error) {
                app.ports.mediaCreated.send(err(error.message));
                console.log(error);

            });
    }

    media.loop = config.loop;
    media.muted = config.muted;
    if (config.volume >= 0.0) {
        if (config.volume > 1.0) {
            media.volume = 1.0;
        } else {
            media.volume = config.volume;
        }
    }
    for (let i = 0; i < config.eventSubs.length; i++) {
        media.addEventListener(config.eventSubs[i], function () { app.ports.stateUpdate.send(mediaToPortState(media)); });
    }

    return media;

}


//This is a custom element for displaying our video, since VirtualDOM is no longer managing our MediaElement
//TODO: Implement the ability to use this node more than once.
class VideoElement extends HTMLElement {
    constructor() {
        super();
        this._media = null;
        this._shadow = this.attachShadow({ mode: 'open' });
    }

    set media(mediaObj) {
        this._media = mediaObj;
        for (let i = 0; i < this.attributes.length; i++) {
            if (this._media.setAttribute) {
                this._media.setAttribute(this.attributes[i].name, this.attributes[i].value);
            }
        }
        if (this._shadow) {
            this._shadow.appendChild(this._media);
        }
    }

    set width(w) {
        if (this._media) {
            this._media.setAttribute("width", w);
        }
    }

    set height(h) {
        if (this._media) {
            this._media.setAttribute("height", h);
        }
    }

    static get observedAttributes() {
        return ["style", "width", "height"];
    }

    attributeChangedCallback(name, old, newValue) {
        if (this._media && this._media.setAttribute) {
            this._media.setAttribute(name, newValue);

        }
    }
}

