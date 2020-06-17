package jolie.lang.parse.ast.types.refinements;

import java.util.ArrayList;

public class BasicTypeRefinementStringList extends BasicTypeRefinement< String > {

	private final ArrayList< String > list = new ArrayList<>();

	public BasicTypeRefinementStringList( ArrayList< String > arrayList ) {
		this.list.addAll( arrayList );
	}

	@Override
	public boolean checkTypeRefinment( String value ) {
		return list.contains( value );
	}

	@Override
	public boolean checkEqualness( BasicTypeRefinement basicTypeRefinement ) {
		if( basicTypeRefinement instanceof BasicTypeRefinementStringList ) {
			BasicTypeRefinementStringList basicTypeRefinementStringList =
				(BasicTypeRefinementStringList) basicTypeRefinement;
			return list.stream().allMatch( s -> basicTypeRefinementStringList.getList().contains( s ) );

		} else {
			return false;
		}
	}

	@Override
	public String getRefinementDocumentationDefinition() {
		return "list([\"item1\",\"item2\",...])";
	}

	public ArrayList< String > getList() {
		return this.list;
	}

}
