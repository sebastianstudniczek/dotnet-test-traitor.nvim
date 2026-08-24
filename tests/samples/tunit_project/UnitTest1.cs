namespace tunit_project;

public class UnitTest1
{
    [Test]
    [Category("Passing")]
    public async Task PassingTest1()
    {
        await Assert.That(true).IsEqualTo(true);
    }

    [Test]
    [Category("Passing")]
    public async Task PassingTest2()
    {
        await Assert.That(true).IsEqualTo(true);
    }

    [Test]
    [Category("Failing")]
    public async Task FailingTest1()
    {
        await Assert.That(false).IsEqualTo(true);
    }

    [Test]
    [Category("Failing")]
    public async Task FailingTest2()
    {
        var act = () => Task.CompletedTask;

        await Assert.That(act).ThrowsExactly<InvalidOperationException>();
    }
}
