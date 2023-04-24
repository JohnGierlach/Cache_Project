import java.util.*;
import java.io.*;

public class TestClass
{
    public static void main(String[] args) throws FileNotFoundException
    {
        ArrayList<Integer> list = scanInAddresses("traces/vortex_trace.txt");
        ArrayList<Integer> newlist = new ArrayList<Integer>(list.subList(0, list.size()));
        System.out.println(newlist.indexOf(Integer.parseInt("7b0345a8", 16)));
    }

    static ArrayList<Integer> scanInAddresses(String traceFile) throws FileNotFoundException
    {
        Scanner scanFile = new Scanner(new File(traceFile));
        ArrayList<Integer> listOfAddresses = new ArrayList<Integer>();
        while(scanFile.hasNext())
        {
            String nextLine = scanFile.nextLine();
            nextLine = nextLine.substring(2);
            int address = Integer.parseInt(nextLine, 16);
            listOfAddresses.add(address);
        }

        return listOfAddresses;
    }
}