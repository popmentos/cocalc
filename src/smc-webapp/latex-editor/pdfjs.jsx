/*
This is a renderer using pdf.js.
*/

import { throttle } from "underscore";

import misc from "smc-util/misc";

import { React, ReactDOM, rclass, rtypes } from "../smc-react";

import { Loading } from "../r_misc";

import pdfjs from "pdfjs-dist/webpack";

/* for dev only */
window.pdfjs = pdfjs;

import util from "../code-editor/util";

export let PDFJS = rclass({
    displayName: "LaTeXEditor-PDFJS",

    propTypes: {
        id: rtypes.string.isRequired,
        actions: rtypes.object.isRequired,
        editor_state: rtypes.immutable.Map,
        is_fullscreen: rtypes.bool,
        project_id: rtypes.string,
        path: rtypes.string,
        reload: rtypes.number,
        font_size: rtypes.number.isRequired
    },

    getInitialState() {
        return {
            num_pages: undefined,
            render: "svg"
        };
    }, // probably only use this, but easy to switch for now for testing.
    //render    : 'canvas'

    shouldComponentUpdate(props, state) {
        return (
            misc.is_different(this.props, props, ["reload", "font_size"]) ||
            misc.is_different(this.state, state, ["num_pages", "render"])
        );
    },

    render_loading() {
        return (
            <div>
                <Loading
                    style={{
                        fontSize: "24pt",
                        textAlign: "center",
                        marginTop: "15px",
                        color: "#888",
                        background: "white"
                    }}
                />
            </div>
        );
    },

    document_load_success(info) {
        this.setState({ num_pages: info.numPages });
    },

    show() {
        $(ReactDOM.findDOMNode(this.refs.scroll)).css("opacity", 1);
    },

    on_item_click(info) {
        console.log("on_item_click", info);
    },

    on_scroll() {
        let elt = ReactDOM.findDOMNode(this.refs.scroll);
        if (elt == null) {
            return;
        }
        elt = $(elt);
        const scroll = { top: elt.scrollTop(), left: elt.scrollLeft() };
        this.props.actions.save_editor_state(this.props.id, { scroll });
    },

    restore_scroll() {
        const scroll = this.props.editor_state?.get("scroll");
        if (!scroll) return;
        let elt = ReactDOM.findDOMNode(this.refs.scroll);
        if (!elt) return;
        elt = $(elt);
        elt.scrollTop(scroll.get("top"));
        elt.scrollLeft(scroll.get("left"));
        this.svg_hack();
    },

    load_first_page(file) {
        // Loading a document.
        const loadingTask = pdfjs.getDocument(file);
        loadingTask.promise
            .then(pdfDocument => {
                // Request a first page
                return pdfDocument.getPage(1).then(pdfPage => {
                    // Display page on the existing canvas with 100% scale.
                    const viewport = pdfPage.getViewport(2.0);
                    const canvas = ReactDOM.findDOMNode(this.refs.canvas);
                    canvas.width = viewport.width;
                    canvas.height = viewport.height;
                    const ctx = canvas.getContext("2d");
                    const renderTask = pdfPage.render({
                        canvasContext: ctx,
                        viewport: viewport
                    });
                    return renderTask.promise;
                });
            })
            .catch(reason => {
                console.error("Error: " + reason);
            });
    },

    componentDidMount() {
        const file =
            util.raw_url(this.props.project_id, this.props.path) +
            "?param=" +
            this.props.reload;
        this.load_first_page(file);
    },

    render() {
        return (
            <div
                style={{
                    overflow: "scroll",
                    margin: "auto",
                    width: "100%",
                    zoom: 0.5 * (this.props.font_size / 12)
                }}
                onScroll={throttle(this.on_scroll, 250)}
                ref={"scroll"}
            >
                <canvas ref={"canvas"} />
            </div>
        );
    }
});