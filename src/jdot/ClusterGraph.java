package jdot;

import jdot.enums.*;
import jdot.impl.*;

public class ClusterGraph extends AbstractGraph {

    public ClusterGraph() {
        super();
    }

    public ClusterGraph(String name) {
        super(name);
    }

    @Override
    public ClusterGraph addNode(Node n) {
        super.addNode(n);
        return this;
    }

    @Override
    public ClusterGraph addNodes(Node... nodes) {
        super.addNodes(nodes);
        return this;
    }

    @Override
    public ClusterGraph addEdge(Edge e) {
        super.addEdge(e);
        return this;
    }

    @Override
    public ClusterGraph addEdge(String name, String... names) {
        super.addEdge(name, names);
        return this;
    }

    @Override
    public ClusterGraph addEdges(Edge... edges) {
        super.addEdges(edges);
        return this;
    }

    public ClusterGraph addSubGraph(SubGraph subGraph) {
        super.addGraph(subGraph);
        return this;
    }

    public ClusterGraph addClusterGraph(ClusterGraph clusterGraph) {
        super.addGraph(clusterGraph);
        return this;
    }

    @Override
    public String toDot() {
        String dot = "subgraph";

        if (getName() != null && getName().length() > 0) {
            if (!getName().startsWith("cluster")) {
                dot = dot + " cluster" + getName();
            } else {
                dot = dot + " " + getName();
            }
        }

        dot = dot + " { ";
        if (getAttrs().has()) {
            dot = dot + "graph [" + getAttrs().getAsString() + "] ";
        }
        for (AbstractElement e : getElements()) {
            dot = dot + e.toDot();
        }
        dot = dot + "} ";
        return dot;
    }

    // Attrs
    public ClusterGraph setK(double k) {
        getAttrs().set(Attrs.Key.K, k);
        return this;
    }

    public ClusterGraph setURL(String url) {
        getAttrs().set(Attrs.Key.URL, url);
        return this;
    }

    public ClusterGraph setArea(double area) {
        getAttrs().set(Attrs.Key.area, area);
        return this;
    }

    public ClusterGraph setBgColor(String color) {
        getAttrs().set(Attrs.Key.bgcolor, color);
        return this;
    }

    public ClusterGraph setBgColor(Color.X11 color) {
        getAttrs().set(Attrs.Key.bgcolor, color);
        return this;
    }

    public ClusterGraph setBgColor(Color.SVG color) {
        getAttrs().set(Attrs.Key.bgcolor, color);
        return this;
    }

    public ClusterGraph setColor(String color) {
        getAttrs().set(Attrs.Key.color, color);
        return this;
    }

    public ClusterGraph setColor(Color.X11 color) {
        getAttrs().set(Attrs.Key.color, color);
        return this;
    }

    public ClusterGraph setColor(Color.SVG color) {
        getAttrs().set(Attrs.Key.color, color);
        return this;
    }

    public ClusterGraph setColorScheme(String scheme) {
        getAttrs().set(Attrs.Key.colorscheme, scheme);
        return this;
    }

    public ClusterGraph setFillColor(String color) {
        getAttrs().set(Attrs.Key.fillcolor, color);
        return this;
    }

    public ClusterGraph setFillColor(Color.X11 color) {
        getAttrs().set(Attrs.Key.fillcolor, color);
        return this;
    }

    public ClusterGraph setFillColor(Color.SVG color) {
        getAttrs().set(Attrs.Key.fillcolor, color);
        return this;
    }

    public ClusterGraph setFontColor(String fontcolor) {
        getAttrs().set(Attrs.Key.fontcolor, fontcolor);
        return this;
    }

    public ClusterGraph setFontColor(Color.X11 fontcolor) {
        getAttrs().set(Attrs.Key.fontcolor, fontcolor);
        return this;
    }

    public ClusterGraph setFontColor(Color.SVG fontcolor) {
        getAttrs().set(Attrs.Key.fontcolor, fontcolor);
        return this;
    }

    public ClusterGraph setFontName(String fontname) {
        getAttrs().set(Attrs.Key.fontname, fontname);
        return this;
    }

    public ClusterGraph setFontSize(double fontsize) {
        getAttrs().set(Attrs.Key.fontsize, fontsize);
        return this;
    }

    public ClusterGraph setGradientAngle(int val) {
        getAttrs().set(Attrs.Key.gradientangle, val);
        return this;
    }

    public ClusterGraph setHref(String val) {
        getAttrs().set(Attrs.Key.href, val);
        return this;
    }

    public ClusterGraph setId(String val) {
        getAttrs().set(Attrs.Key.id, val);
        return this;
    }

    public ClusterGraph setLabel(String label) {
        getAttrs().set(Attrs.Key.label, label);
        return this;
    }

    public ClusterGraph setLabelJust(Position.X val) {
        getAttrs().set(Attrs.Key.labeljust, val);
        return this;
    }

    public ClusterGraph setLabelLoc(Position.Y val) {
        getAttrs().set(Attrs.Key.labelloc, val);
        return this;
    }

    public ClusterGraph setLayer(String val) {
        getAttrs().set(Attrs.Key.layer, val);
        return this;
    }

    public ClusterGraph setLHeight(double val) {
        getAttrs().set(Attrs.Key.lheight, val);
        return this;
    }

    public ClusterGraph setLp(String val) {
        getAttrs().set(Attrs.Key.lp, val);
        return this;
    }

    public ClusterGraph setLWidth(double val) {
        getAttrs().set(Attrs.Key.lwidth, val);
        return this;
    }

    public ClusterGraph setMargin(double val) {
        getAttrs().set(Attrs.Key.margin, val);
        return this;
    }

    public ClusterGraph setMargin(String val) {
        getAttrs().set(Attrs.Key.margin, val);
        return this;
    }

    public ClusterGraph setNoJustify(boolean flag) {
        getAttrs().set(Attrs.Key.nojustify, flag);
        return this;
    }

    public ClusterGraph setPenColor(String color) {
        getAttrs().set(Attrs.Key.pencolor, color);
        return this;
    }

    public ClusterGraph setPenColor(Color.X11 color) {
        getAttrs().set(Attrs.Key.pencolor, color);
        return this;
    }

    public ClusterGraph setPenColor(Color.SVG color) {
        getAttrs().set(Attrs.Key.pencolor, color);
        return this;
    }

    public ClusterGraph setPenWidth(double val) {
        getAttrs().set(Attrs.Key.penwidth, val);
        return this;
    }

    public ClusterGraph setPeripheries(int val) {
        getAttrs().set(Attrs.Key.peripheries, val);
        return this;
    }

    public ClusterGraph setSortV(int val) {
        getAttrs().set(Attrs.Key.sortv, val);
        return this;
    }

    public ClusterGraph setStyle(Style.ClusterGraph style) {
        getAttrs().set(Attrs.Key.style, style);
        return this;
    }

    public ClusterGraph setTarget(String val) {
        getAttrs().set(Attrs.Key.target, val);
        return this;
    }

    public ClusterGraph setToolTip(String val) {
        getAttrs().set(Attrs.Key.tooltip, val);
        return this;
    }
}
