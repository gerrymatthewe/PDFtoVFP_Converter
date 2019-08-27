/* PDFHomePageCSS */

a:link
{
    color: white;
    text-decoration: none;
}

a:visited
{
    color: white;
    text-decoration: none;
}

a:hover
{
    color: white !important;
    text-decoration: underline dotted white !important;
    cursor: pointer;
}

.pageBody
{
    background-color: #777887;
}

.checkBoxes
{
    color:white;
    padding: 10px 15px 10px 10px;
}

#homePageContainer
{
    text-align:center;
}

#upload-button, #tableHolder
{
    margin:auto;
    margin-top: 100px;
}

#tableName
{
    color: white;
    text-align:center;
    margin-top: 50px;
}

#tableHolder
{
    font-family: "Trebuchet MS", Arial, Helvetica, sans-serif;
    border-collapse: collapse;
    padding-top: 20px;
    width: 75%;
}

#tableHolder td, #tableHolder th
{
    border: 1px solid #ddd;
    padding: 8px;
    text-align: center;
}

#tableHolder tr:hover
{
    background-color: rgba(221, 221, 221, .5);
}

#tableHolder th
{
    padding-top: 12px;
    padding-bottom: 12px;
    background-color: #17a2b8;
    color: white;
}

.overlay
{
    /* Height and width depends on how you want to reveal the overlay (see JS below) */
    height: 0%;
    width: 100%;
    position: fixed; /* Stay in place */
    z-index: 1; /* Sit on top */
    left: 0;
    top: 0;
    background-color: rgb(0,0,0); /* Black fallback color */
    background-color: rgba(0,0,0, 0.6); /* Black w/opacity */
    overflow-x: hidden; /* Disable horizontal scroll */
    transition: 0.5s; /* 0.5 second transition effect to slide in or slide down the overlay (height or width, depending on reveal) */
}

.overlay-content
{
    position: relative;
    top: 25%;
    width: 100%;
    text-align: center;
    margin-top: 30px;
}

#conversion-info, #pdfInfo, #tableHolder, #profileInfo, #profileErrors
{
    color: white;
    font-size: 14pt;
}

#tableHolder
{
    margin-top: 20px;
}

#newVF, #failButton
{
    display: none;
}

.circle-loader
{
    position: relative;
    display: inline-block;
    vertical-align: top;
    margin-bottom: 56px;
    border: 1px solid rgba(0, 0, 0, 0.2);
    border-left-color: #5cb85c;
    animation: loader-spin 1.2s infinite linear;
    border-radius: 50%;
    width: 112px;
    height: 112px;
}

.load-complete
{
    -webkit-animation: none;
    animation: none;
    border-color: #5cb85c;
    transition: border 500ms ease-out;
}

.load-fail
{
    -webkit-animation: none;
    animation: none;
    border-color: red;
    transition: border 500ms ease-out;
}

.checkmark
{
    display: none;
}

.checkmark .draw:after
{
    animation-duration: 800ms;
    animation-timing-function: ease;
    animation-name: checkmark;
    transform: scaleX(-1) rotate(135deg);
}

.checkmark:after
{
    opacity: 1;
    height: 56px;
    width: 28px;
    transform-origin: left top;
    border-right: 3px solid #5cb85c;
    border-top: 3px solid #5cb85c;
    content: '';
    left: 28px;
    top: 56px;
    position: absolute;
}


@keyframes loader-spin
{
    0% {
        transform: rotate(0deg);
    }
    100% {
        transform: rotate(360deg);
    }
}

@keyframes checkmark
{
    0% {
        height: 0;
        width: 0;
        opacity: 1;
    }
    20% {
        height: 0;
        width: 28px;
        opacity: 1;
    }
    40% {
        height: 56px;
        width: 28px;
        opacity: 1;
    }
    100% {
        height: 56px;
        width: 28px;
        opacity: 1;
    }
}