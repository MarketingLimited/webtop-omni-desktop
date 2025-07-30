import { Button } from "@/components/ui/button";
import { Monitor, Terminal, Wifi } from "lucide-react";

const HeroSection = () => {
  return (
    <div className="relative min-h-screen bg-gradient-hero flex items-center justify-center overflow-hidden">
      {/* Background Pattern */}
      <div className="absolute inset-0 opacity-40" style={{
        backgroundImage: `url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='0.02'%3E%3Ccircle cx='30' cy='30' r='1'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")`
      }}></div>
      
      <div className="relative z-10 text-center space-y-8 px-6 max-w-4xl mx-auto">
        <div className="space-y-4 animate-fade-in">
          <div className="flex items-center justify-center space-x-2 mb-6">
            <Monitor className="w-8 h-8 text-primary" />
            <Terminal className="w-8 h-8 text-accent" />
            <Wifi className="w-8 h-8 text-primary" />
          </div>
          
          <h1 className="text-5xl md:text-7xl font-bold bg-gradient-to-r from-foreground to-foreground/80 bg-clip-text text-transparent">
            Cloud Desktop
          </h1>
          <p className="text-xl md:text-2xl text-muted-foreground max-w-2xl mx-auto">
            Dockerized Ubuntu KDE desktop with Linux, Android, and Windows app support - 
            accessible from any web browser
          </p>
        </div>
        
        <div className="flex flex-col sm:flex-row gap-4 justify-center items-center">
          <Button variant="hero" size="lg" className="min-w-[200px]">
            Get Started
          </Button>
          <Button variant="outline" size="lg" className="min-w-[200px]">
            View Documentation
          </Button>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-16 text-sm">
          <div className="flex items-center justify-center space-x-2 text-muted-foreground">
            <div className="w-2 h-2 bg-primary rounded-full animate-glow"></div>
            <span>Zero Dependencies</span>
          </div>
          <div className="flex items-center justify-center space-x-2 text-muted-foreground">
            <div className="w-2 h-2 bg-accent rounded-full animate-glow"></div>
            <span>Multi-Platform Apps</span>
          </div>
          <div className="flex items-center justify-center space-x-2 text-muted-foreground">
            <div className="w-2 h-2 bg-primary rounded-full animate-glow"></div>
            <span>Web-Based Access</span>
          </div>
        </div>
      </div>
    </div>
  );
};

export default HeroSection;