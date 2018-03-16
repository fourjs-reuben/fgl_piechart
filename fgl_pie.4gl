IMPORT FGL fglsvgcanvas
IMPORT util

PUBLIC TYPE sliceType RECORD
        color STRING,
        offset FLOAT,
        text_style_color STRING, 
        text_style_font_name STRING,
        text_style_font_size INTEGER
END RECORD

PUBLIC TYPE pie_rec RECORD
    data_col_count INTEGER,
    data_row_count INTEGER,
    data_column DYNAMIC ARRAY OF RECORD
        type STRING,
        label STRING,
        role STRING
    END RECORD,

    data DYNAMIC ARRAY WITH DIMENSION 2 OF STRING,

    background_color RECORD 
        stroke_width INTEGER,
        stroke STRING,
        fill STRING
    END RECORD,
    chart_area RECORD
        background_color RECORD
            stroke STRING,
            stroke_width INTEGER
        END RECORD,
        left INTEGER,
        top INTEGER,
        width INTEGER,
        height INTEGER
    END RECORD,
    colors DYNAMIC ARRAY OF STRING,
    enableInteractivity BOOLEAN,
    font_size INTEGER,
    font_name STRING,
    forceIFrame BOOLEAN,
    height INTEGER,
    is3d BOOLEAN,
    legend RECORD
        alignment STRING,
        position STRING,
        max_lines INTEGER,
        text_style RECORD
            color STRING,
            font_name STRING,
            font_size INTEGER,
            weight STRING,
            font_style STRING
        END RECORD
    END RECORD,
    pie_hole FLOAT,
    pie_slice RECORD
        border_color STRING,
        border_width INTEGER,
        text STRING,
        text_style RECORD
            color STRING,
            font_name STRING,
            font_size INTEGER
        END RECORD
    END RECORD,
    pie_start_angle FLOAT,
    reverse_categories BOOLEAN,
    pie_residue_slice_color STRING,
    pie_residue_slice_label STRING,
    slices DYNAMIC ARRAY OF sliceTYPE,

    slice_visibility_threshold FLOAT,
    title STRING,
    title_position RECORD
        x INTEGER,
        y INTEGER,
        alignment STRING
    END RECORD,
    title_text_style RECORD
        color STRING,
        font_name STRING,
        font_size INTEGER,
        weight STRING,
        font_style STRING
    END RECORD,
    tooltip RECORD
        ignore_bounds BOOLEAN,
        is_html BOOLEAN,
        show_color_code BOOLEAN,
        text STRING,
        text_style RECORD
            color STRING,
            font_name STRING,
            font_size INTEGER,
            weight STRING,
            font_style STRING
        END RECORD,
        trigger STRING
    END RECORD,
    width INTEGER
END RECORD

FUNCTION draw(fieldname, pie)
DEFINE fieldname STRING
DEFINE pie pie_rec

DEFINE root, slice, legend, legend_circle, txt, pie_hole om.DomNode
DEFINE cid SMALLINT

DEFINE a1,a2, a_inc, ao, cx,cy,ox,oy,rx,ry, x1,y1,x2,y2, xl, yl, xg, yg, x_tmp, y_tmp FLOAT
DEFINE residue, total FLOAT
DEFINE i INTEGER

DEFINE large_arc_flag, sweep_flag SMALLINT
DEFINE slice_text STRING
DEFINE bbox_result STRING
DEFINE bbox RECORD
    x,y,width,height FLOAT
END RECORD

    -- TODO these maybe moved out so can draw two pies on same canvas
    CALL fglsvgcanvas.initialize()
    LET cid = fglsvgcanvas.create(fieldname)
    LET root = fglsvgcanvas.setRootSVGAttributes("myrootsvg",
    NULL, NULL,
    SFMT("0 0 %1 %2",pie.width, pie.height),
    "xMidYMid meet")

    -- Calculate center and radius
    LET cx=  pie.chart_area.left + (pie.chart_area.width / 2)
    LET cy=  pie.chart_area.top + (pie.chart_area.height / 2)
    LET rx = pie.chart_area.width / 2
    LET ry = pie.chart_area.height / 2

    -- Calculate total
    LET total = 0.0
    FOR i = 1 TO pie.data_row_count
        LET total = total + nvl(pie.data[i,2],0)
    END FOR

    -- Do residue calculations
    LET residue = 0.0
    FOR i  = pie.data_row_count TO 1 STEP -1
        IF pie.data[i,2] < pie.slice_visibility_threshold THEN
            -- Delete individual slice and add value to residue
            LET residue = residue + pie.data[i,2]
            CALL pie.data.deleteElement(i)
            CALL pie.slices.deleteElement(i)
        END IF
    END FOR

    -- Add residue as last slice if any
    IF residue > 0.0 THEN
        LET i = pie.slices.getLength() + 1
        LET pie.data[i,1] = nvl(pie.pie_residue_slice_label,"Other")
        LET pie.data[i,2] = residue
        LET pie.slices[i].color = nvl(pie.pie_residue_slice_color,"grey")
    END IF

    LET legend = fglsvgcanvas.createElement("g","legend")
    CALL root.appendChild(legend)
    CASE pie.legend.position -- Set starting values for variable that will increment     
        WHEN "left" 
            LET xg = pie.chart_area.left - 10 
            LET yg  =pie.chart_area.top
        WHEN "right" 
            LET xg = pie.chart_area.left + pie.chart_area.width + 10 
            LET yg = pie.chart_area.top
        WHEN "top" 
            LET xg = pie.chart_area.left
            LET yg = pie.chart_area.top - 10
        WHEN "bottom" 
            LET xg = pie.chart_area.left
            LET yg = pie.chart_area.top + pie.chart_area.height + 10
    END CASE

    -- Do background fill
    CALL root.setAttribute(SVGATT_STYLE,SFMT("background-color:%1", nvl(pie.background_color.fill,"white")))

    -- Draw individual slices
    LET a1 = nvl(pie.pie_start_angle-90,-90)
    FOR i = 1 TO pie.data_row_count
        LET a_inc = (360*pie.data[i,2] / total)

        IF pie.reverse_categories THEN
            LET a_inc = -a_inc
        END IF
       
        LET a2 = a1 + a_inc

        -- If offset, move cxm cy out
        LET ao = a1 + (a_inc/2)
        IF pie.slices[i].offset > 0 THEN
            LET ox = cx+(rx*util.Math.cos(util.Math.pi()*ao/180)*pie.slices[i].offset)
            LET oy = cy+(ry*util.Math.sin(util.Math.pi()*ao/180)*pie.slices[i].offset)
        ELSE
            LET ox = cx
            LET oy = cy
        END IF
       
        LET x1 = ox + rx*util.Math.cos(util.Math.pi()*a1/180)
        LET y1 = oy + ry*util.Math.sin(util.Math.pi()*a1/180)

        LET x2 = ox + rx*util.Math.cos(util.Math.pi()*a2/180)
        LET y2 = oy + ry*util.Math.sin(util.Math.pi()*a2/180)

        LET large_arc_flag = IIF(a_inc>180,1,IIF(a_inc<-180,1,0))
        LET sweep_flag = 1

        IF pie.reverse_categories THEN
            -- Swp x,y so still drawing clockwise
            LET x_tmp = x1  LET y_tmp = y1
            LET x1 = x2     LET y1 = y2
            LET x2 = x_tmp  LET y2 = y_tmp
        END IF

        LET slice = fglsvgcanvas.path(SFMT("M%1 %2 L%3 %4 A%5 %6 0 %9 %10 %7 %8 L%1 %2",ox,oy,x1,y1,rx,ry,x2,y2,large_arc_flag, sweep_flag))
        CALL slice.setAttribute(SVGATT_STYLE,SFMT("fill:%1; stroke: %2; stroke-width:%3px", nvl(pie.slices[i].color, pie.colors[i]),nvl(pie.pie_slice.border_color,"white"),nvl(pie.pie_slice.border_width,0)))

        -- Add responsiveness
        CALL slice.setAttribute("id", pie.data[i,1]) -- perhaps ahave a dedicated id column in data
        CALL slice.setAttribute("onclick","elem_clicked(this)")
        CALL slice.setAttribute("onmouseover","elem_mouse_over(this)")
        CALL slice.setAttribute("onmouseout","elem_mouse_out(this)")


        CALL root.appendChild(slice)

        -- Add label 
        -- Position = 
        IF nvl(pie.pie_slice.text,"none") = "none" THEN
            # No Label
        ELSE
            LET xl = ox+rx*util.Math.cos(util.Math.pi()*ao/180)*.7
            LET yl = oy+ry*util.Math.sin(util.Math.pi()*ao/180)*.7

            CASE pie.pie_slice.text
                WHEN "value"
                    LET slice_text = pie.data[i,2]
                WHEN "label"
                    LET slice_text = pie.data[i,1]
                WHEN "percentage"
                    LET slice_text = (pie.data[i,2] / total * 100) USING "##&.&%"
                -- TODO add custom
            END CASE
            LET txt = fglsvgcanvas.text(xl, yl, slice_text, NULL)
            CALL txt.setAttribute("text-anchor","middle")
            IF pie.pie_slice.text_style.color IS NOT NULL THEN
                CALL txt.setAttribute("fill",pie.pie_slice.text_style.color)
            END IF
            IF pie.pie_slice.text_style.font_name IS NOT NULL THEN
                CALL txt.setAttribute("font-family",pie.pie_slice.text_style.font_name)
            END IF
            IF pie.pie_slice.text_style.font_size IS NOT NULL THEN
                CALL txt.setAttribute("font-size",pie.pie_slice.text_style.font_size)
            END IF

            CALL root.appendChild(txt)
        END IF

        -- Draw legend   
        IF nvl(pie.legend.position,"none") = "none" THEN
            #Dont draw legend
        ELSE
            -- Set position Before
            CASE 
                WHEN pie.legend.position = "left" OR pie.legend.position = "right"
                   # Do after
                WHEN pie.legend.position = "bottom" OR pie.legend.position = "top"
                   # Do after
                WHEN pie.legend.position ="labeled"
                    LET xg = ox+rx*util.Math.cos(util.Math.pi()*ao/180)*1.3
                    LET yg = oy+ry*util.Math.sin(util.Math.pi()*ao/180)*1.3
            END CASE

            IF  pie.legend.position = "labeled" THEN
                -- No need to draw circle
            ELSE
                LET legend_circle = fglsvgcanvas.circle(xg+nvl(pie.legend.text_style.font_size,12)/2,yg-nvl(pie.legend.text_style.font_size,12)/2,nvl(pie.legend.text_style.font_size,12)/2)  #TODO replace 12 with default font size
                CALL legend_circle.setAttribute("fill",nvl(pie.slices[i].color, pie.colors[i]))
                CALL root.appendChild(legend_circle)
                LET xg = xg + nvl(pie.legend.text_style.font_size,12) + 3  #TODO Replace 12 with default font size
            END IF

            LET txt = fglsvgcanvas.text(xg, yg, pie.data[i,1], NULL)
            CALL txt.setAttribute("text-anchor","left")
            IF pie.legend.text_style.color IS NOT NULL THEN
                CALL txt.setAttribute("fill",IIF(pie.legend.text_style.color = "slice",nvl(pie.slices[i].color, pie.colors[i]),pie.legend.text_style.color))
            END IF
            IF pie.legend.text_style.font_name IS NOT NULL THEN
                CALL txt.setAttribute("font-family",pie.legend.text_style.font_name)
            END IF
            IF pie.legend.text_style.font_size IS NOT NULL THEN
                CALL txt.setAttribute("font-size",pie.legend.text_style.font_size)
            END IF
            IF pie.legend.text_style.weight IS NOT NULL THEN
                CALL txt.setAttribute("font-weight", pie.legend.text_style.weight)  
            END IF
            IF pie.legend.text_style.font_style IS NOT NULL THEN
                CALL txt.setAttribute("font-style",pie.legend.text_style.font_style)
            END IF
            CALL txt.setAttribute("id",SFMT("legend_%1", pie.data[i,1]))
            CALL root.appendChild(txt)
            
            -- Set position After
            CASE 
                WHEN pie.legend.position = "left" OR pie.legend.position = "right"
                    LET yg = yg + 18 -- TODO
                    -- Add wrap case
                WHEN pie.legend.position = "bottom" OR pie.legend.position = "top"
                    -- Get bounding box position of text
                    CALL fglsvgcanvas.display(cid)
                    CALL ui.Interface.frontCall("webcomponent","call",["formonly.wc","get_bbox","myrootsvg",SFMT("legend_%1", pie.data[i,1])],bbox_result)                   
                    TRY
                        CALL util.JSON.parse(bbox_result, bbox)
                    CATCH
                        INITIALIZE bbox TO NULL
                    END TRY
                    LET xg = bbox.x + bbox.width + 3 
                    -- Add wrap case
                    IF xg > (pie.chart_area.left + pie.chart_area.width-nvl(pie.legend.text_style.font_size,12)) THEN
                        LET yg = yg + 18
                        LET xg = pie.chart_area.left
                    END IF
                WHEN pie.legend.position ="labeled"
                    # Do Before
            END CASE
        END IF

        -- TODO tooltip

        LET a1 = a2
    END FOR

    -- Draw pie hole by drawing background color over top
    IF pie.pie_hole > 0 THEN
        LET pie_hole = fglsvgcanvas.ellipse(cx,cy,rx*pie.pie_hole, ry*pie.pie_hole)
        CALL pie_hole.setAttribute(SVGATT_STYLE,SFMT("fill:%1; stroke: %2; stroke-width:%3", nvl(pie.background_color.fill,"white"),nvl(pie.pie_slice.border_color,"black"),"0px"))
        CALL root.appendChild(pie_hole)
    END IF

    IF pie.title IS NOT NULL THEN
        IF pie.title_position.x IS NULL THEN
            LET pie.title_position.x =  cx
        END IF
        IF pie.title_position.y IS NULL THEN
            LET pie.title_position.y =  cy - ry - 6
        END IF
        LET txt = fglsvgcanvas.text(pie.title_position.x, pie.title_position.y, pie.title,  NULL)
        CALL txt.setAttribute("text-anchor", nvl(pie.title_position.alignment,"middle"))

        IF pie.title_text_style.color IS NOT NULL THEN
            CALL txt.setAttribute("fill",pie.title_text_style.color)
        END IF
        IF pie.title_text_style.font_name IS NOT NULL THEN
            CALL txt.setAttribute("font-family",pie.title_text_style.font_name)
        END IF
        IF pie.title_text_style.font_size IS NOT NULL THEN
            CALL txt.setAttribute("font-size",pie.title_text_style.font_size)
        END IF
        IF pie.title_text_style.weight IS NOT NULL THEN
            CALL txt.setAttribute("font-weight", pie.title_text_style.weight)  
        END IF
        IF pie.title_text_style.font_style IS NOT NULL THEN
            CALL txt.setAttribute("font-style",pie.title_text_style.font_style)
        END IF
        
        CALL root.appendChild(txt)
    END IF

    --CALL root.appendChild(legend)

    CALL fglsvgcanvas.display(cid)
END FUNCTION

