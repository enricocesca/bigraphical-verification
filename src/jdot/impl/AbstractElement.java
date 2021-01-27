package jdot.impl;

public abstract class AbstractElement {

    public AbstractElement() {
        _attrs = new Attrs();
    }

    public Attrs getAttrs() {
        return _attrs;
    }

    public abstract String toDot();
    
    /**
     * @author enricocesca
     */
    public abstract boolean isNode();

    /**
     * @author enricocesca
     */
    public abstract boolean isEdge();
    
    private final Attrs _attrs;
}
