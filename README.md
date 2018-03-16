# fgl_piechart
Sample Pie Chart library built on top of fglsvgcanvas

Based on the Pie Chart example from https://github.com/FourjsGenero/wc_googlecharts, this example will show how you can build your own graphical library that meets your needs on top of fglsvgcanvas.

When running, click Example1, .., Example8 to see some examples.
You can then modify any of the parameters on the left hand side and click Draw to draw the new chart

Notes:
If you use legend position = top, bottom, you will need to make the following changes to the fglsvgcanvas Web Component.  Add the following function. 


```javascript
get_bbox = function(id_svg,id) {
    try {
        var svg = document.getElementById(id_svg);
        var svg_node = svg.getElementById(id);
        var svg_bbox = svg_node.getBBox();
        var bbox = {};
        for (key in svg_bbox) {
                bbox[key] = svg_bbox[key]
        }
        return bbox;
    }
    catch (err) {
        return null;
    }
}
```

This is used by code like the following to return the bounding box of an svg element so that objects can be placed alongside, in particular alongside svgtext objects

```
DEFINE bbox RECORD
    x,y,width,height FLOAT
END RECORD

CALL ui.Interface.frontCall("webcomponent","call",["formonly.wc","get_bbox","myrootsvg",SFMT("legend_%1", pie.data[i,1])],bbox_result)                   
TRY
    CALL util.JSON.parse(bbox_result, bbox)
CATCH
    INITIALIZE bbox TO NULL
END TRY
```

Note sure if I will continue with this technique above but it is only way I can think of to draw objects at the end of a svgtext element, as with svgtext you do not know the width.  This technique is required in the legend area where you might have Circle Text Circle Text



