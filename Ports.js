const MediaControl = { 
    setup : 
        function(app){
            if (app.ports.toJs.subscribe){
                app.ports.toJs.subscribe(respondToElm);
            }
            customElements.define("video-element", VideoElement);
        }
};


function decodeTimeRanges(ranges){
    let decoded = [];
    if (ranges instanceof TimeRanges) {
    for (let i = 0; i < ranges.length; i++){
        decoded.push({start: ranges.start(i), end: ranges.end(i)});
    }
    }
    return decoded;
}

function mediaToPortState(md){
    return {currentTime: md.currentTime,
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
    played: decodeTimeRanges(md.played)};
}

function ok(result){
    return {result: "OK", data: result};
}

function err(result){
    return {result: "ERR", data: result};
}

function respondToElm(msg) {
    switch (msg.command) {
    case "CREATE":
        let media = createMedia(msg.data);
        globalMedia = media;
        if (media != null){
        app.ports.mediaCreated.send(ok(media));
        } else {
        app.ports.mediaCreated.send(err("Couldn't Create Media."));
        }
        break;

    case "CHANGE_SETTING":
        if (msg.data.mediaObj) {
        switch (msg.data.setting) {
            case "PLAY":
            msg.data.mediaObj.play();
            break;
            case "PAUSE":
            msg.data.mediaObj.pause();
            break;
            default:
            msg.data.mediaObj[msg.data.setting] = msg.data.value;
            break;
        }
        app.ports.stateUpdate.send(mediaToPortState(msg.data.mediaObj));
        }
    case "GET_STATE":
        if (msg.data.mediaObj) {
        app.ports.stateUpdate.send(mediaToPortState(msg.data.mediaObj));
        }
        break;
    default:
        break;

    }
}

function decodePlaybackState(med){
    if (med.paused == true) {
    return "PAUSED";
    } else {
    if (med.err){
        return med.err.message;
    } else if (med.ended) {
        return "ENDED";
    } else if (med.readyState < 0){
        return "LOADING";
    } else if (med.readyState == 2){
        return "BUFFERING";
    } else {
        return "PLAYING";
    }
    }
}

function createUrlSource(src){
    let urlSource = document.createElement("source");
    urlSource.setAttribute("src", src.url);
    if (src.type) {
        urlSource.setAttribute("type", (typeToString(src)));
    }
    return urlSource;
}

function typeToString(src) {
    var t ="";
    if (src.type) {
    t = src.type;
    if (src.codecs) {
        t = t + ";codecs=\"" + src.codecs +"\"";
    }
    }
    return t;
}

function createMedia(config) {
    let media = document.createElement("video");

    if (config.source.url) {
    let urlSource = createUrlSource(config.source);
    media.appendChild(urlSource);
    } else if (config.source.urls) {
    console.log(config.source.urls);
    let urlSource;
    for(let i = 0; i<config.source.urls.length; i++){
        urlSource = createUrlSource(config.source.urls[i]);
        media.appendChild(urlSource);
    }
    } else if (config.source.captureStream){
        navigator.mediaDevices.getUserMedia = navigator.mediaDevices.getUserMedia || navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia;

        if (!navigator.mediaDevices.getUserMedia) {
        return {error: "USER_MEDIA_NOT_SUPPORTED"};
        }
        
        setTimeout(function(){ return {error: "USER_APPROVAL_TIMEOUT"}; }, 60000);
        navigator.mediaDevices.getUserMedia(config.source.captureStream)
            .then(function(stream){
                try{
                media.srcObject = stream;
                } catch (error) {
                console.log(error);
                media.src = URL.createObjectURL(stream);
                }
                media.play();
            }).catch(function(error){
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
    for(let i=0; i<config.eventSubs.length; i++){
    media.addEventListener(config.eventSubs[i], function(){app.ports.stateUpdate.send(mediaToPortState(media));});
    }

    return media;

}

class VideoElement extends HTMLElement {
    constructor() {
        super();
        this._media = null;
        this._shadow = this.attachShadow({mode: 'open'});
    }

    set media(mediaObj){
        this._media = mediaObj;
        for (let i = 0; i < this.attributes.length; i++){
            if (this._media.setAttribute){
                this._media.setAttribute(this.attributes[i].name, this.attributes[i].value);
            }
        }
        if(this._shadow){
            this._shadow.appendChild(this._media);
        }
    }

    set width(w){
        if(this._media){
            this._media.setAttribute("width", w);
        }
    }

    set height(h){
        if(this._media){
            this._media.setAttribute("height", h);
        }
    }

    static get observedAttributes() {
        return ["style", "width", "height"];
    }

    attributeChangedCallback(name, old, newValue){
        if (this._media && this._media.setAttribute && !disallowedAttributes.includes(name)){
                this._media.setAttribute(name, newValue);
            
        }
    }
}

