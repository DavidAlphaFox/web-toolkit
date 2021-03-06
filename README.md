<h2 align="center">Lisp Web Toolkit</h2>

<p align="center">
    <a href="https://lisp-web-toolkit.com">lisp-web-toolkit.com</a>
</p>

<p align="center">
Object-Oriented Reactive Lisp Systems for Rapid Web Application Development
</p>

### Status

**Layer 1**: (*Work in Progress*) Rich set of features for fundamental Web-related technologies

HTTP, WebSocket, URI, JSON, DOM, HTML, CSS, JavaScript

**Layer 2**: (*Experimeltal*) Component abstraction and reactive behavior

Component, Live

**Layer 3**: (*Planning*) Integration with enterprise-class vendor libraries

[Ant Design](https://ant.design/), [Ant Vision](https://antv.vision/en), ...

### Systems

#### [HTTP](https://lisp-web-toolkit.com/#http)
WT.HTTP provides HTTP functionality based on [RFC 7231 Hypertext Transfer Protocol (HTTP/1.1)](https://www.ietf.org/rfc/rfc7231.txt), together with implementation of server and client.

#### [WebSocket](https://lisp-web-toolkit.com/#websocket)
WT.WEBSOCKET provides WebSocket functionality based on [RFC 6455 The WebSocket Protocol](https://tools.ietf.org/html/rfc6455), with interface inspired by [JSR 356, Java API for WebSocket](https://www.oracle.com/technetwork/articles/java/jsr356-1937161.html). The system is tested against the [Autobahn WebSocket Testsuite](https://github.com/crossbario/autobahn-testsuite).

#### [HTML](https://lisp-web-toolkit.com/#html)
WT.HTML implements HTML constructor, parser and serializer. The parser is designed to conform to the [WHATWG HTML Specification](https://html.spec.whatwg.org/multipage/), as is implemented by all major web browsers. It uses the Document Object Model (DOM) provided by WT.DOM.

#### [JSON](https://lisp-web-toolkit.com/#json)
WT.JSON implements JSON encoder and decoder based on [ECMA-404 The JSON Data Interchange Standard](https://www.json.org/json-en.html). It distinguishes `null`, `false` and `[]` from Lisp's `NIL` thus supports identical transformation between JSON values. It provides object constructor and accessor to build and access nesting JSON objects. The system is tested against [JSONTestSuite](https://github.com/nst/JSONTestSuite).

#### [URI](https://lisp-web-toolkit.com/#uri)
WT.URI provides URI parser, render and constructor with support for UTF-8 characters, IPv6 addresses and query parameters handling. It utilizes recursive descent [parser combinators](https://www.cs.nott.ac.uk/~pszgmh/monparsing.pdf) to provide a concise implementation that is close to the definition in [RFC 3986 Uniform Resource Identifier (URI): Generic Syntax](https://tools.ietf.org/html/rfc3986).

#### [CSS](https://lisp-web-toolkit.com/#css)
WT.CSS implements CSS constructor, parser and serializer based on specifications introduced in [CSS Snapshot 2018](https://www.w3.org/TR/css-2018/#css).

#### [JavaScript](https://lisp-web-toolkit.com/#javascript)
WT.JAVASCRIPT implements JavaScript parser and serializer based on [ECMAScript 2016 Language Specification](https://www.ecma-international.org/ecma-262/7.0/) (ECMA-262 7th Edition) with support for [JSX](https://reactjs.org/docs/introducing-jsx.html) syntax extension. It utilizes syntax tree components from the [ESTree](https://github.com/estree/estree) project.

#### [DOM](https://lisp-web-toolkit.com/#dom)
WT.DOM implements Document Object Model (DOM) based on recent version of [DOM Living Standard](https://dom.spec.whatwg.org/), it covers chapters on [Nodes](https://dom.spec.whatwg.org/#nodes) and [Traversal](https://dom.spec.whatwg.org/#traversal).

#### [Component](https://lisp-web-toolkit.com/#component)
WT.COMPONENT provices component abstraction, it combines [Web Components](https://developer.mozilla.org/en-US/docs/Web/Web_Components) style strong encapsulation and [React](https://reactjs.org/) style declarative DOM synchronization.

### Roadmap

* Overall
  * Use in production environments
  * Write [documentation](https://lisp-web-toolkit.com)
  * Carefully design conditions and errors
  * Write more tests
  * <s>Add project build status graph</s>
  * Add code coverage informataion
* HTTP
  * Use [Asynchronous I/O](http://www.lispworks.com/documentation/lw71/LW/html/lw-192.htm) in LispWorks
  * Use [Recursive Event Dispatching (SERVE-EVENT)](https://github.com/sbcl/sbcl/blob/master/src/code/serve-event.lisp) in SBCL 
  * Abandon usocket & bordeaux-threads, write implementation-dependent code
  * Implement server statistics and metrics monitoring
  * Implement traffic throttling and message size limiting
  * Implement authentication, authorization and access control
  * Implement static file serving
  * Implement cache control
  * Implement compression
  * Implement logging
  * Implement [HTTP/2](https://tools.ietf.org/html/rfc7540)
  * Implement common handlers
  * Implement virtual host
  * <s>(Client) Support HTTPS</s>
  * (Client) Support compression and decompression
  * (Client) Support HTTP Proxy
  * (Client) Support SOCKS Proxy
  * (Client) Support Basic Auth
  * (Client) Implement Cookie store
  * (Client) Support caching
* WebSocket
  * Use [Asynchronous I/O](http://www.lispworks.com/documentation/lw71/LW/html/lw-192.htm) in LispWorks
  * Use [Recursive Event Dispatching (SERVE-EVENT)](https://github.com/sbcl/sbcl/blob/master/src/code/serve-event.lisp) in SBCL
  * Implement server statistics and metrics monitoring
  * Implement traffic throttling and message size limiting
  * Support [Compression Extensions](https://tools.ietf.org/html/rfc7692)
  * Support WSS for both client and server
* URI
  * Test against [Web Platform Tests](https://github.com/web-platform-tests/wpt)
* HTML
  * <s>Implement parser</s>
  * <s>Implement pretty print(?) (NO)</s>
  * Refine element constractor error report
  * <s>Implement DOM, abandon CXML's DOM implementation</s>
  * Test against [Web Platform Tests](https://github.com/web-platform-tests/wpt)
* JSON
  * <s>Test against [JSONTestSuite](https://github.com/nst/JSONTestSuite)</s>
  * <s>Implement accessors for object</s>
  * <s>Implement identical transformation for JSON values (null, false, [])</s>
* DOM
  * Implement common used functions
  * Implement namespace
  * Implement XPath
* JavaScript
  * Implement JavaScript <=> S-expression code transformer
* CSS
  * Parse common used property values and implement CSSOM

### Author
[Xiangyu He](https://xh.coobii.com) <[xh@coobii.com](mailto:xh@coobii.com)>

### License
Copyright 2018-2020 Xiangyu He. Released under the 3-Clause BSD License.
