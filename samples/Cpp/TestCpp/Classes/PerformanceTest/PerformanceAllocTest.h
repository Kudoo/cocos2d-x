/*
 *
 */
#ifndef __PERFORMANCE_ALLOC_TEST_H__
#define __PERFORMANCE_ALLOC_TEST_H__

#include "PerformanceTest.h"
#include "support/CCProfiling.h"

class AllocBasicLayer : public PerformBasicLayer
{
public:
    AllocBasicLayer(bool bControlMenuVisible, int nMaxCases = 0, int nCurCase = 0);

    virtual void showCurrentTest();
};

class PerformceAllocScene : public Scene
{
public:
    virtual void initWithQuantityOfNodes(unsigned int nNodes);
    virtual std::string title();
    virtual std::string subtitle();
    virtual void updateQuantityOfNodes() = 0;

    const char* profilerName();
    void updateProfilerName();

    // for the profiler
    virtual const char* testName() = 0;

    void updateQuantityLabel();

    int getQuantityOfNodes() { return quantityOfNodes; }

    void dumpProfilerInfo(float dt);

    // overrides
    virtual void onExitTransitionDidStart() override;
    virtual void onEnterTransitionDidFinish() override;

protected:
    char   _profilerName[256];
    int    lastRenderedCount;
    int    quantityOfNodes;
    int    currentQuantityOfNodes;
};

class NodeCreateTest : public PerformceAllocScene
{
public:
    virtual void updateQuantityOfNodes();
    virtual void initWithQuantityOfNodes(unsigned int nNodes);
    virtual void update(float dt);
    virtual const char* testName();

    std::string title();
    std::string subtitle();
};

class NodeDeallocTest : public PerformceAllocScene
{
public:
    virtual void updateQuantityOfNodes();
    virtual void initWithQuantityOfNodes(unsigned int nNodes);
    virtual void update(float dt);
    virtual const char* testName();

    std::string title();
    std::string subtitle();
};

class SpriteCreateTest : public PerformceAllocScene
{
public:
    virtual void updateQuantityOfNodes();
    virtual void initWithQuantityOfNodes(unsigned int nNodes);
    virtual void update(float dt);
    virtual const char* testName();

    std::string title();
    std::string subtitle();
};

class SpriteDeallocTest : public PerformceAllocScene
{
public:
    virtual void updateQuantityOfNodes();
    virtual void initWithQuantityOfNodes(unsigned int nNodes);
    virtual void update(float dt);
    virtual const char* testName();

    std::string title();
    std::string subtitle();
};


void runAllocPerformanceTest();

#endif // __PERFORMANCE_ALLOC_TEST_H__
