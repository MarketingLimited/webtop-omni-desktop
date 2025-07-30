import HeroSection from "@/components/HeroSection";
import ServicesGrid from "@/components/ServicesGrid";
import FeaturesSection from "@/components/FeaturesSection";
import GettingStarted from "@/components/GettingStarted";
import ConfigurationHelper from "@/components/ConfigurationHelper";

const Index = () => {
  return (
    <div className="min-h-screen bg-background">
      <HeroSection />
      <ServicesGrid />
      <FeaturesSection />
      <GettingStarted />
      <ConfigurationHelper />
    </div>
  );
};

export default Index;
