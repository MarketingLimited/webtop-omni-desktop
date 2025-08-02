import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Monitor, Terminal, Server, ExternalLink, Play } from "lucide-react";

const ServicesGrid = () => {
  const services = [
    {
      title: "KDE Desktop",
      description: "Full Ubuntu 24.04 + KDE Plasma desktop environment",
      icon: Monitor,
      url: "http://localhost:32768",
      port: "32768",
      status: "active",
      features: ["KasmVNC Client", "Graphics Acceleration", "Audio Support"]
    },
    {
      title: "Terminal",
      description: "Web-based terminal with ttyd",
      icon: Terminal,
      url: "http://localhost:7681",
      port: "7681",
      status: "active",
      features: ["Full Shell Access", "File Management", "System Control"]
    },
    {
      title: "SSH Access",
      description: "Direct SSH connection to the container",
      icon: Server,
      url: "ssh://localhost:2222",
      port: "2222",
      status: "active",
      features: ["Secure Connection", "Port Forwarding"]
    }
  ];

  const getStatusColor = (status: string) => {
    switch (status) {
      case "active":
        return "bg-green-500/20 text-green-400 border-green-500/30";
      case "inactive":
        return "bg-red-500/20 text-red-400 border-red-500/30";
      default:
        return "bg-yellow-500/20 text-yellow-400 border-yellow-500/30";
    }
  };

  return (
    <div className="py-24 px-6">
      <div className="max-w-6xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-4xl font-bold mb-4">Access Your Services</h2>
          <p className="text-xl text-muted-foreground max-w-2xl mx-auto">
            Connect to your containerized desktop environment through multiple access points
          </p>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {services.map((service, index) => {
            const IconComponent = service.icon;
            return (
              <Card key={index} className="bg-gradient-card border-border shadow-card hover:shadow-elevated transition-all duration-300 p-6 group">
                <div className="space-y-4">
                  <div className="flex items-start justify-between">
                    <div className="flex items-center space-x-3">
                      <div className="p-2 bg-primary/20 rounded-lg">
                        <IconComponent className="w-6 h-6 text-primary" />
                      </div>
                      <div>
                        <h3 className="font-semibold text-card-foreground">{service.title}</h3>
                        <p className="text-sm text-muted-foreground">Port {service.port}</p>
                      </div>
                    </div>
                    <Badge className={getStatusColor(service.status)}>{service.status}</Badge>
                  </div>
                  
                  <p className="text-sm text-muted-foreground">{service.description}</p>
                  
                  <div className="space-y-2">
                    {service.features.map((feature, idx) => (
                      <div key={idx} className="flex items-center space-x-2 text-xs">
                        <div className="w-1 h-1 bg-accent rounded-full"></div>
                        <span className="text-muted-foreground">{feature}</span>
                      </div>
                    ))}
                  </div>
                  
                  <div className="flex gap-2 pt-2">
                    <Button 
                      variant="service" 
                      size="sm" 
                      className="flex-1 group-hover:bg-secondary"
                      onClick={() => window.open(service.url, '_blank')}
                    >
                      <Play className="w-4 h-4" />
                      Connect
                    </Button>
                    <Button variant="ghost" size="sm">
                      <ExternalLink className="w-4 h-4" />
                    </Button>
                  </div>
                </div>
              </Card>
            );
          })}
        </div>
      </div>
    </div>
  );
};

export default ServicesGrid;