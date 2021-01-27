package it.uniud.mads.jlibbig.core.std;

import java.util.Collection;

import it.uniud.mads.jlibbig.core.Owned;

/**
 * Handles are link entities identifying the hyper-edges that compose link
 * graphs and that link points. Handles are outer names or edges depending on
 * whereas they belong to an outer interface or not.
 */
public interface Handle extends Owned, LinkEntity,
		it.uniud.mads.jlibbig.core.Handle {

	@Override
	public abstract Collection<? extends Point> getPoints();

	public abstract EditableHandle getEditable();
}
